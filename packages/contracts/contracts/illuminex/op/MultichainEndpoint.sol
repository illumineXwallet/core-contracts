// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./celer/message/interfaces/IMessageBus.sol";
import '../../interfaces/IWROSE.sol';
import "../../libraries/FeesCollector.sol";
import "../chainvault/CrossChainVaultApp.sol";
import "./IMultichainEndpoint.sol";
import "../../confidentialERC20/ERC2771Context.sol";

contract MultichainEndpoint is IMultichainEndpoint, FeesCollector, ERC2771Context {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint64 public constant SAPPHIRE_CHAINID_TESTNET = 0x5aff;
    uint64 public constant SAPPHIRE_CHAINID_MAINNET = 0x5afe;

    uint64 public immutable SAPPHIRE_CHAINID;

    enum MultichainCommandType {
        ProxyPass,
        Receive
    }

    enum MessageStoreType {
        MessageReceived,
        MultichainMessageSent
    }

    struct ConnectEndpointParams {
        uint64 chainId;
        address contractAddress;
    }

    struct EndpointFee {
        uint256 settlementCost; // tx total cost on dst chain in dst chain currency
        uint256 settlementCostInLocalCurrency; // tx total cost on dst chain in current chain's currency
    }

    struct SetEndpointFee {
        uint64 chainId;
        EndpointFee fee;
    }

    address public nativeWrapper;
    address public feeSetter;

    mapping(uint64 => address) public connectedEndpoints;
    mapping(address => uint64) public chainIdByEndpointAddress;

    mapping(MessageStoreType => mapping(bytes32 => bool)) public settledMessages;

    mapping(bytes32 => bool) internal _executedMessages;
    mapping(bytes32 => bool) public _failedMessages;
    mapping(bytes32 => address) private _messageRawHashToSender;
    mapping(bytes32 => address) internal _dataHashToSender;

    mapping(address => bool) public allowedSenders;

    mapping(uint64 => EndpointFee) public endpointsDestinationFees;

    CrossChainVaultApp public immutable vaultApp;
    address public immutable messageBus;

    event MessageReceived(bytes32 indexed hashedEventKey, bool hasFailed);
    event MultichainMessageSent(bytes32 indexed hashedEventKey);
    event FeeUpdated(SetEndpointFee[] feeData);

    constructor(address payable _vaultApp, bool isTestnet) ERC2771Context(address(0)) {
        vaultApp = CrossChainVaultApp(_vaultApp);
        messageBus = CrossChainVaultApp(_vaultApp).messageBus();
        feeSetter = msg.sender;

        SAPPHIRE_CHAINID = isTestnet ? SAPPHIRE_CHAINID_TESTNET : SAPPHIRE_CHAINID_MAINNET;
    }

    function toggleAllowedSender(address _sender) public onlyOwner {
        allowedSenders[_sender] = !allowedSenders[_sender];
    }

    function setTrustedForwarder(address _forwarder) public onlyOwner {
        _setTrustedForwarder(_forwarder);
    }

    function setNativeWrapper(address _wrapper) public onlyOwner {
        nativeWrapper = _wrapper;
    }

    function setConnectedEndpoints(ConnectEndpointParams[] memory _endpoints) public onlyOwner {
        for (uint i = 0; i < _endpoints.length; i++) {
            require(_endpoints[i].chainId != block.chainid, "Can't add an endpoint to the current chain");
            connectedEndpoints[_endpoints[i].chainId] = _endpoints[i].contractAddress;
            chainIdByEndpointAddress[_endpoints[i].contractAddress] = _endpoints[i].chainId;
        }
    }

    function setFeeSetter(address _feeSetter) public onlyOwner {
        feeSetter = _feeSetter;
    }

    function setFixedFee(SetEndpointFee[] calldata feeData) public {
        require(msg.sender == feeSetter, "Not allowed");

        for (uint i = 0; i < feeData.length; i++) {
            require(feeData[i].fee.settlementCost > 0 && feeData[i].fee.settlementCostInLocalCurrency > 0, "Zero");
            endpointsDestinationFees[feeData[i].chainId] = feeData[i].fee;
        }

        emit FeeUpdated(feeData);
    }

    function _multichainProxyPass(address token, uint256 amount, bytes memory data, uint256 fees) private {
        address sapphireEndpoint = connectedEndpoints[SAPPHIRE_CHAINID];
        require(sapphireEndpoint != address(0), "Sapphire endpoint is not yet configured");

        bytes memory celerData = abi.encode(
            _msgSender(),
            fees,
            data
        );

        bytes memory bridgeTemplate = abi.encode(uint8(0), address(0), uint256(0));

        uint _feesByCeler = IMessageBus(messageBus).calcFee(abi.encode(bridgeTemplate, celerData));
        require(
            fees >= _feesByCeler + endpointsDestinationFees[SAPPHIRE_CHAINID].settlementCostInLocalCurrency,
            "Value is too low"
        );

        celerData = abi.encode(
            _msgSender(),
            fees - _feesByCeler,
            data
        );

        _depositFees(fees - _feesByCeler);

        IERC20(token).safeIncreaseAllowance(address(vaultApp), amount);
        vaultApp.lockAndMint{value: _feesByCeler}(
            connectedEndpoints[SAPPHIRE_CHAINID],
            SAPPHIRE_CHAINID,
            token,
            amount,
            celerData
        );

        _messageRawHashToSender[keccak256(celerData)] = _msgSender();

        settledMessages[MessageStoreType.MultichainMessageSent][keccak256(data)] = true;
        emit MultichainMessageSent(keccak256(data));
    }

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) public virtual payable {
        require(allowedSenders[msg.sender], "Sender is not allowed");

        uint256 feesValue = msg.value;
        if (token == nativeWrapper) {
            require(msg.value >= amount, "Insufficient native amount");
            IWROSE(nativeWrapper).deposit{value: amount}();
            feesValue -= amount;
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        require(block.chainid != SAPPHIRE_CHAINID, "Can't proxy pass from Sapphire");
        _multichainProxyPass(token, amount, encodedParams, feesValue);
    }

    function executeMessageWithTransfer(
        address _token,
        uint256 _amount,
        uint64 srcChainId,
        bytes memory _message
    ) external override payable returns (CallbackExecutionStatus) {
        require(msg.sender == address(vaultApp), "Unauthorized vault app");
        require(!_executedMessages[keccak256(_message)], "Callback already executed");

        (address sender, uint256 fee, bytes memory data) = _preprocessPayloadData(_message);

        (bytes memory header,) = abi.decode(data, (bytes, bytes));
        (uint8 commandTypeRaw) = abi.decode(header, (uint8));
        MultichainCommandType commandType = MultichainCommandType(commandTypeRaw);

        _executedMessages[keccak256(_message)] = true;
        _dataHashToSender[keccak256(data)] = sender;

        if (commandType == MultichainCommandType.ProxyPass) {
            uint256 convertedFee =
                fee *
                endpointsDestinationFees[srcChainId].settlementCostInLocalCurrency
                / endpointsDestinationFees[srcChainId].settlementCost;

            return _handleProxyPass(
                data, 
                _amount, 
                _token,
                convertedFee
            );
        } else if (commandType == MultichainCommandType.Receive) {
            return _handleReceive(data, _token, _amount, false);
        }

        return CallbackExecutionStatus.Failed;
    }

    function executeMessageWithTransferFallback(
        address _token,
        uint256 _amount,
        bytes calldata _message
    ) external payable virtual override returns (CallbackExecutionStatus) {
        require(msg.sender == address(vaultApp), "Unauthorized vault app");

        require(!_executedMessages[keccak256(_message)], "Callback already executed");

        (,, bytes memory data) = _preprocessPayloadData(_message);

        return _handleReceive(data, _token, _amount, true);
    }

    function _preprocessPayloadData(bytes memory data) internal virtual view returns(address, uint256, bytes memory) {
        return (address(0), 0, data);
    }

    function _beforeCommandExecution(
        MultichainCommandType cmd,
        bytes memory data,
        address token,
        uint256 amount
    ) internal virtual {}

    function _decodeProxyPassCommand(
        bytes memory _entry
    ) internal pure returns (uint64, address, uint256, uint256, uint8) {
        return abi.decode(_entry, (uint64, address, uint256, uint256, uint8));
    }

    function _encodeReceiveCommand(address dstAddress, bytes32 keyIndex) internal pure returns (bytes memory) {
        return abi.encode(abi.encode(uint8(MultichainCommandType.Receive)), abi.encode(keyIndex, dstAddress));
    }

    receive() external payable {}

    function _transferTokensTo(address _to, address _token, uint256 _amount) internal {
        if (_token == nativeWrapper) {
            IWROSE(_token).withdraw(_amount);
            payable(_to).transfer(_amount);

            return;
        }

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _handleReceive(
        bytes memory _data,
        address _token,
        uint256 _amount,
        bool failure
    ) internal returns (CallbackExecutionStatus) {
        (, bytes memory body) = abi.decode(_data, (bytes, bytes));
        (bytes32 keyIndex, address dstAddress) = abi.decode(body, (bytes32, address));

        emit MessageReceived(keyIndex, failure);
        settledMessages[MessageStoreType.MessageReceived][keyIndex] = true;

        _transferTokensTo(dstAddress, _token, _amount);

        return CallbackExecutionStatus.Success;
    }

    function _handleProxyPass(
        bytes memory,
        uint256,
        address,
        uint256
    ) internal virtual returns (CallbackExecutionStatus) {
        return CallbackExecutionStatus.Success;
    }
}
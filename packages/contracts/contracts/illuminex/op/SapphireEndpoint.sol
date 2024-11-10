// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./MultichainEndpoint.sol";
import "./celer/message/interfaces/IMessageBus.sol";
import "../../confidentialERC20/PrivateWrapperFactory.sol";
import "./IComplianceManager.sol";
import "./IEndpointReceiverHook.sol";

contract SapphireEndpoint is MultichainEndpoint {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    bytes32[] private _ringKeys;
    uint256 private _lastRingKeyUpdate;

    mapping(address => bool) public isExcludedFromFees;
    mapping(IEndpointReceiverHook => bool) public hooks;

    uint8 public constant MAX_WITHDRAWAL_FEE = 10;
    uint256 public protocolFees = 0;

    uint256 public ringKeyUpdateInterval = 1 days;

    enum ProxyPassOutputType {
        QueuedUnwrapped,
        QueuedWrapped,
        Instant
    }

    struct ProxyPassOutput {
        address to;
        uint256 amount;
        uint64 chainId;
        uint256 extra;
        ProxyPassOutputType kind;
    }

    struct ProxyPassRequestParams {
        bytes32 nonce;
        address[] swapPath;
        ProxyPassOutput[] outputs;
    }

    bytes public constant ENC_CONST = "ILLUMINEX_V2";
    string public constant RECORD_TYPE = "OPL_EVM_ENDPOINT";

    IComplianceManager public immutable complianceManager;
    PrivateWrapperFactory public immutable wrapperFactory;

    event ActualRingKeyRenewed(uint indexed newKeyIndex);
    event RingKeyUpdateIntervalChange(uint256 newInterval);

    event ComplianceRecordLog(address indexed sender, bytes32 recordId);

    event FeesChanged(uint256 from, uint256 to);

    constructor(
        address payable _wrapperFactory,
        address payable _vault,
        address _complianceManager,
        bytes32 _genesis,
        bool isTestnet
    ) MultichainEndpoint(_vault, isTestnet) {
        wrapperFactory = PrivateWrapperFactory(_wrapperFactory);
        complianceManager = IComplianceManager(_complianceManager);
        _updateRingKey(_genesis);
    }

    function toggleFeesExclusion(address _user) public onlyOwner {
        isExcludedFromFees[_user] = !isExcludedFromFees[_user];
    }

    function enableHook(IEndpointReceiverHook _hook) public onlyOwner {
        hooks[_hook] = true;
    }

    function setFees(uint256 _newFees) public onlyOwner {
        require(_newFees <= MAX_WITHDRAWAL_FEE, "Fees are too high");

        emit FeesChanged(protocolFees, _newFees);
        protocolFees = _newFees;
    }

    function setRingKeyUpdateInterval(uint256 _newInterval) public onlyOwner {
        ringKeyUpdateInterval = _newInterval;
        emit RingKeyUpdateIntervalChange(_newInterval);
    }

    function _updateRingKey(bytes32 _entropy) private {
        bytes32 newKey = bytes32(Sapphire.randomBytes(32, abi.encodePacked(_entropy)));

        uint newIndex = _ringKeys.length;
        _ringKeys.push(newKey);

        _lastRingKeyUpdate = block.timestamp;

        emit ActualRingKeyRenewed(newIndex);
    }

    function _renewActualRingKey(bytes32 _entropy) private {
        if (_lastRingKeyUpdate + ringKeyUpdateInterval > block.timestamp) {
            return;
        }

        _updateRingKey(_entropy);
    }

    function _computeNonce(uint256 keyIndex) private pure returns (bytes32 nonce) {
        nonce = keccak256(abi.encodePacked(keyIndex, ENC_CONST));
    }

    function _decrypt(bytes memory _keyData) private view returns (uint256 ringKeyIndex, bytes memory output) {
        (uint256 _ringKeyIndex, bytes memory _encryptedData) = abi.decode(_keyData, (uint256, bytes));
        require(_ringKeyIndex < _ringKeys.length, "No ring key found");

        bytes32 nonce = _computeNonce(_ringKeyIndex);

        output = Sapphire.decrypt(_ringKeys[_ringKeyIndex], nonce, _encryptedData, ENC_CONST);
        ringKeyIndex = _ringKeyIndex;
    }

    function _preprocessPayloadData(
        bytes memory data
    ) internal virtual override view returns(address sender, uint256 fee, bytes memory output) {
        (address _sender, uint256 _fee, bytes memory _keyData) = abi.decode(data, (address, uint256, bytes));
        (, bytes memory _output) = _decrypt(_keyData);

        output = _output;
        fee = _fee;
        sender = _sender;
    }

    function encryptPayload(bytes memory payload) private view returns (bytes memory encryptedData, uint256 keyIndex) {
        require(_ringKeys.length > 0, "No ring keys set up");

        keyIndex = _ringKeys.length - 1;
        bytes32 nonce = _computeNonce(keyIndex);
        encryptedData = Sapphire.encrypt(_ringKeys[keyIndex], bytes32(nonce), payload, abi.encodePacked(ENC_CONST));
    }

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) public override payable {
        uint256 feesValue = msg.value;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        require(block.chainid == SAPPHIRE_CHAINID, "Can pass only from Sapphire");

        _depositFees(feesValue);

        (, bytes memory data) = _decrypt(encodedParams);
        _dataHashToSender[keccak256(data)] = msg.sender;

        uint256 _protocolFees = amount * protocolFees / 1000;
        if (isExcludedFromFees[msg.sender]) {
            _protocolFees = 0;
        } else {
            IERC20(token).safeTransfer(owner(), _protocolFees);
        }

        require(_handleProxyPass(data, amount - _protocolFees, token, feesValue) != CallbackExecutionStatus.Failed, "Failed");
    }

    function executeMessageWithTransferFallback(
        address _token,
        uint256 _amount,
        bytes calldata _message
    ) external payable virtual override returns (CallbackExecutionStatus _status) {
        require(msg.sender == address(vaultApp), "Unauthorized vault app");

        require(!_executedMessages[keccak256(_message)], "Callback already executed");

        (address sender,,) = _preprocessPayloadData(_message);

        _executedMessages[keccak256(_message)] = true;
        _failedMessages[keccak256(_message)] = true;

        _transferTokensTo(sender, _token, _amount);
        _status = CallbackExecutionStatus.Failed;
    }

    function prepareEncryptedParams(
        ProxyPassRequestParams memory params
    ) public view returns (bytes memory encoded, uint256 keyIndex) {
        require(params.outputs.length > 0, "Invalid outputs list");

        bytes memory header = abi.encode(uint8(MultichainCommandType.ProxyPass), params.nonce, params.swapPath);
        bytes[] memory bodyParts = new bytes[](params.outputs.length);

        for (uint i = 0; i < params.outputs.length; i++) {
            ProxyPassOutput memory output = params.outputs[i];
            bodyParts[i] = abi.encode(output.chainId, output.to, output.amount, output.extra, uint8(output.kind));
        }

        (encoded, keyIndex) = encryptPayload(abi.encode(header, bodyParts));
    }

    function _submitEncryptedReport(address _sender, bytes[] memory _outputs) private {
        bytes32 recordId = complianceManager.pushRecord(RECORD_TYPE, abi.encode(_outputs));
        emit ComplianceRecordLog(_sender, recordId);
    }

    function _finalizeOutput(
        bytes32 keyIndex,
        address _token,
        uint256 amount,
        uint64 dstChainId,
        address dstAddress,
        bytes32 _data
    ) private {
        if (dstChainId == SAPPHIRE_CHAINID) {
            IERC20(_token).safeTransfer(dstAddress, amount);
            if (hooks[IEndpointReceiverHook(dstAddress)]) {
                IEndpointReceiverHook(dstAddress).hook(_token, amount, bytes.concat(_data));
            }

            return;
        }

        if (wrapperFactory.tokenByWrapper(_token) != address(0)) {
            wrapperFactory.unwrapERC20(_token, amount, address(this));
            _token = wrapperFactory.tokenByWrapper(_token);
        }

        bytes memory encodedData = _encodeReceiveCommand(dstAddress, keyIndex);
        bytes memory bridgeTemplate = abi.encode(uint8(0), address(0), uint256(0));

        uint _feesByCeler = IMessageBus(messageBus).calcFee(abi.encode(bridgeTemplate, encodedData));

        IERC20(_token).safeIncreaseAllowance(address(vaultApp), amount);

        vaultApp.burnAndUnlock{value: _feesByCeler}(
            connectedEndpoints[dstChainId],
            dstChainId,
            _token,
            amount,
            encodedData
        );

        emit MultichainMessageSent(keyIndex);
        settledMessages[MessageStoreType.MultichainMessageSent][keyIndex] = true;
    }

    function _extractDepIndexFromEntry(bytes memory _entry) private pure returns (uint256) {
        (,,,uint256 _depIndex,) = _decodeProxyPassCommand(_entry);
        return _depIndex;
    }

    function _handleProxyPass(
        bytes memory _data,
        uint256 _totalAmount,
        address _token,
        uint256 fee
    ) internal virtual override returns (CallbackExecutionStatus) {
        (bytes memory header, bytes[] memory entries) = abi.decode(_data, (bytes, bytes[]));
        (, bytes32 _nonce,) = abi.decode(header, (uint8, bytes32, address[]));

        if (entries.length == 0) {
            return CallbackExecutionStatus.Failed;
        }

        emit MessageReceived(keccak256(abi.encodePacked(_nonce, entries.length)), false);
        settledMessages[MessageStoreType.MessageReceived][keccak256(abi.encodePacked(_nonce, entries.length))] = true;

        _renewActualRingKey(keccak256(abi.encodePacked(_data, _totalAmount, _token, fee)));
        _submitEncryptedReport(_dataHashToSender[keccak256(_data)], entries);

        // Wrap the source token to the confidential wrapper
        IERC20(_token).approve(address(wrapperFactory), _totalAmount);
        if (address(wrapperFactory.tokenByWrapper(_token)) == address(0)) {
            wrapperFactory.wrapERC20(_token, _totalAmount, address(this));
        }

        _token = address(wrapperFactory.tokenByWrapper(_token)) != address(0)
            ? _token
            : address(wrapperFactory.wrappers(_token));

        {
            uint256 _totalAmountByEntries = 0;
            uint256 totalDstGasFee = 0;
            for (uint i = 0; i < entries.length; i++) {
                (uint64 dstChainId, address dstAddress, uint256 amount,,) = _decodeProxyPassCommand(entries[i]);

                address dstContract = connectedEndpoints[dstChainId];
                if (dstChainId != SAPPHIRE_CHAINID) {
                    require(dstContract != address(0), "Unsupported endpoint");
                }

                _totalAmountByEntries += amount;

                if (dstChainId != SAPPHIRE_CHAINID) {
                    totalDstGasFee += endpointsDestinationFees[dstChainId].settlementCostInLocalCurrency
                        + IMessageBus(messageBus).calcFee(
                            abi.encode(
                                abi.encode(uint8(0), address(0), uint256(0)), // lock-and-mint header
                                _encodeReceiveCommand(dstAddress, keccak256(ENC_CONST))
                            )
                        );
                }
            }

            if (totalDstGasFee > 0) {
                require(totalDstGasFee <= fee, "Insufficient fee provided");
            }

            // Received amount after can't exceed the transferred amount
            require(_totalAmountByEntries <= _totalAmount, "Entries amount does not match the total amount");

            if (_totalAmount > _totalAmountByEntries) {
                (
                    uint64 dstChainId,
                    address dstAddress,
                    uint256 amount,
                    uint256 extra,
                    uint8 kind
                ) = _decodeProxyPassCommand(
                    entries[entries.length - 1]
                );

                amount += (_totalAmount - _totalAmountByEntries);
                entries[entries.length - 1] = abi.encode(dstChainId, dstAddress, amount, extra, kind);
            }
        }

        IERC20(_token).safeIncreaseAllowance(address(wrapperFactory), _totalAmount);

        {
            for (uint i = 0; i < entries.length; i++) {
                (uint64 dstChainId, address dstAddress, uint256 amount, uint256 extra,) = _decodeProxyPassCommand(entries[i]);
                if (amount == 0) {
                    continue;
                }

                _finalizeOutput(keccak256(
                    abi.encodePacked(_nonce, dstChainId, dstAddress, i)),
                    _token,
                    amount,
                    dstChainId,
                    dstAddress,
                    bytes32(extra)
                );
            }
        }

        return CallbackExecutionStatus.Success;
    }
}

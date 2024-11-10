// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ISealedEncryptor.sol";

contract EncryptedDeployer {
    ISealedEncryptor public immutable encryptor;

    constructor(address _encryptor) {
        encryptor = ISealedEncryptor(_encryptor);
    }

    function deploy(bytes calldata encryptedInitCode) public {
        bytes memory initCode = encryptor.decryptForMe(encryptedInitCode);
        if (initCode.length < 20) {
            return;
        }

        bytes memory data = new bytes(encryptedInitCode.length - 20);
        for (uint i = 20; i < initCode.length; i++) {
            data[i - 20] = initCode[i];
        }

        address factory = address(bytes20(initCode));
        (bool success,) = factory.call(data);

        require(success, "Failed to deploy");
    }
}

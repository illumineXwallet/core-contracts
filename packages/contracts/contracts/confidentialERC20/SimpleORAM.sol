// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";

library SimpleORAMLib {
    uint8 constant private DECOYS_COUNT = 5;

    struct SimpleORAM {
        mapping(bytes32 => bytes32) kv;
        mapping(bytes32 => bytes32) decoy;
        bytes32[] allKeys;
    }

    function set(SimpleORAM storage self, address key, uint256 value) internal {
        set(self, bytes32(bytes20(key)), bytes32(value));
    }

    function set(SimpleORAM storage self, bytes32 key, bytes32 value) internal {
        self.allKeys.push(key);

        uint256 _realIndex = uint256(
            bytes32(Sapphire.randomBytes(32, abi.encodePacked(key, block.number, self.allKeys.length, "STR")))
        ) % DECOYS_COUNT;

        for (uint i = 0; i < DECOYS_COUNT; i++) {
            uint256 _unboundedDecoyIndex = uint256(
                bytes32(Sapphire.randomBytes(32, abi.encodePacked(key, i, block.number, self.allKeys.length)))
            );

            bytes32 _fakeKey = self.allKeys[_unboundedDecoyIndex % self.allKeys.length];

            if (_realIndex % 2 == 0) {
                if (i == _realIndex) {
                    self.kv[key] = value;
                }
            }

            self.decoy[_fakeKey] = value;
            if (_realIndex % 2 != 0) {
                if (i == _realIndex) {
                    self.kv[key] = value;
                }
            }
        }
    }

    function get(SimpleORAM storage self, address key) internal view returns (uint256) {
        return uint256(get(self, bytes32(bytes20(key))));
    }

    function get(SimpleORAM storage self, bytes32 key) internal view returns (bytes32) {
        bytes32 _realValue = bytes32(0);
        bytes32 _decoyValue = bytes32(0);

        uint256 _realIndex = uint256(
            bytes32(Sapphire.randomBytes(32, abi.encodePacked(key, block.number, self.allKeys.length, "STR")))
        ) % DECOYS_COUNT;

        for (uint i = 0; i < DECOYS_COUNT; i++) {
            uint256 _unboundedDecoyIndex = uint256(
                bytes32(Sapphire.randomBytes(32, abi.encodePacked(key, i, block.number, self.allKeys.length)))
            );

            bytes32 _fakeKey;
            if (self.allKeys.length > 0) {
                uint256 _fakeIndex = _unboundedDecoyIndex % self.allKeys.length;
                _fakeKey = self.allKeys[_fakeIndex];
            }

            if (_realIndex % 2 == 0) {
                if (i == _realIndex) {
                    _realValue = self.kv[key];
                }
            }

            if (self.allKeys.length > 0) {
                _decoyValue = self.kv[_fakeKey];
            }

            if (_realIndex % 2 != 0) {
                if (i == _realIndex) {
                    _realValue = self.kv[key];
                }
            }
        }

        return _realValue;
    }
}

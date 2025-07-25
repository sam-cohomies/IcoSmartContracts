// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

library ChmAffiliateCodes {
    error InvalidCodeLength(string code);
    error InvalidCodeCharacter(string code, uint8 index, bytes1 character);

    string public constant ALLOWED_CHARACTERS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    uint8 public constant ALLOWED_CHARACTERS_LENGTH = 31;
    uint8 public constant CHM_AFFILIATE_CODE_LENGTH = 4;
    uint24 public constant MAX_SEED_COUNT = uint24(ALLOWED_CHARACTERS_LENGTH ** CHM_AFFILIATE_CODE_LENGTH);
    uint24 public constant STEP_SIZE = 3_065_857; // 37*41*43*47, coprime to MAX_SEED_COUNT

    function getCodeFromSeed(uint24 seed) internal pure returns (string memory codeString) {
        bytes memory code = new bytes(CHM_AFFILIATE_CODE_LENGTH);
        for (uint8 i = 0; i < CHM_AFFILIATE_CODE_LENGTH; ++i) {
            code[i] = bytes(ALLOWED_CHARACTERS)[seed % ALLOWED_CHARACTERS_LENGTH];
            seed /= ALLOWED_CHARACTERS_LENGTH;
        }
        codeString = string(code);
    }

    function getSeedFromCode(string calldata code) internal pure returns (uint24 seed) {
        if (bytes(code).length != CHM_AFFILIATE_CODE_LENGTH) {
            revert InvalidCodeLength(code);
        }
        seed = 0;
        for (uint8 i = 0; i < CHM_AFFILIATE_CODE_LENGTH; ++i) {
            bytes1 character = bytes(code)[i];
            uint8 index = findCharacterIndex(character);
            if (index == ALLOWED_CHARACTERS_LENGTH) {
                revert InvalidCodeCharacter(code, i, character);
            }
            seed = seed * ALLOWED_CHARACTERS_LENGTH + index;
        }
    }

    function findCharacterIndex(bytes1 character) internal pure returns (uint8 i) {
        for (i = 0; i < ALLOWED_CHARACTERS_LENGTH; ++i) {
            if (character == bytes(ALLOWED_CHARACTERS)[i]) {
                return i;
            }
        }
        revert InvalidCodeCharacter("", 0, character);
    }

    function generateSeed(address marketer, mapping(uint24 => address) storage existingSeeds)
        internal
        view
        returns (uint24 seed)
    {
        seed = uint24(uint160(marketer)) % MAX_SEED_COUNT;
        address existingSeed = existingSeeds[seed];
        while (existingSeed != address(0)) {
            if (existingSeed == marketer) {
                return seed;
            }
            seed = (seed * STEP_SIZE) % MAX_SEED_COUNT;
            existingSeed = existingSeeds[seed];
        }
    }
}

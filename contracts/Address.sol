// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

library Address {
    function isContract(address account) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
pragma solidity >=0.4.22 <0.7.0;

import '../common/SafeMath.sol';


library itMaps {

    using SafeMath for *;

    struct entryAddressUnit256 {
        uint256 keyIndex;
        uint256 value;
        address receipt;
        string currency;
    }
    
    struct itMapAddressUint256 {
        mapping(bytes32 => entryAddressUnit256) data;
        bytes32[] keys;
    }

    function remove(itMapAddressUint256 storage self, bytes32 key) internal returns (bool success) {
        entryAddressUnit256 storage e = self.data[key];
        if (e.keyIndex == 0)
            return false;
        if (e.keyIndex <= self.keys.length) {
            // Move an existing element into the vacated key slot.
            self.data[self.keys[self.keys.length - 1]].keyIndex = e.keyIndex;
            self.keys[e.keyIndex - 1] = self.keys[self.keys.length - 1];
            self.keys.pop();
            delete self.data[key];
            return true;
        }
    }

    function upSert(itMapAddressUint256 storage self, uint256 value, address receipt, string memory currency) internal returns (bool success) {
        
        bytes32 key = keccak256(abi.encode(receipt,currency));
        
        entryAddressUnit256 storage e = self.data[key];
        if (e.keyIndex > 0) {
            e.value = e.value.add(value);
        } else {
            e.value = value;
            e.receipt = receipt;
            e.currency = currency;
            e.keyIndex = self.keys.length + 1;
            self.keys.push(key);
        }
        return true;
    }
    
    function resetValue(itMapAddressUint256 storage self, uint256 idx) internal returns (bool success){
        self.data[self.keys[idx]].value = 0;
        return true;
    }

    function size(itMapAddressUint256 storage self) internal view returns (uint256) {
        return self.keys.length;
    }

    function getKeyByIndex(itMapAddressUint256 storage self, uint256 idx) internal view returns (bytes32) {
        return self.keys[idx];
    }

    function getItemByIndex(itMapAddressUint256 storage self, uint256 idx) internal view returns (entryAddressUnit256 memory) {
        return self.data[self.keys[idx]];
    }
    
    function destroy(itMapAddressUint256 storage self) internal  {
        for (uint i; i<self.keys.length; i++) {
          delete self.data[ self.keys[i]];
        }
        delete self.keys;
        return ;
    }

}
pragma solidity >=0.4.22 <0.7.0;

pragma experimental ABIEncoderV2;

import "./PayTypes.sol";
import "../common/Owner.sol";

contract MerchantManager is Owner,PayTypes {
    
    // merchantKey => Merchant
    mapping(string => Merchant) merchantMap;
    
    function getMerchant(string memory merchantKey) public view returns(Merchant memory){
        return merchantMap[merchantKey];
    }
    
    function setMerchant(string memory key,address recept,address refer) isOwnerOrAdmin external{
        Merchant memory _m = Merchant(key,recept,refer);
        merchantMap[key] = _m;
    }
    
}
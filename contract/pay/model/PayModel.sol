pragma solidity >=0.4.22 <0.7.0;

pragma experimental ABIEncoderV2;

import "../../common/SeroInterface.sol";
import "../../common/SafeMath.sol";
import "../../common/Owner.sol";

import "../PayTypes.sol";

contract PayModel is PayTypes,Owner{
    
    Model private model ;
    AddrConfig private addrConfig;
     
    constructor(address exchangeAddress,address invokeAddress,address mallAddress,address t1Address) public{
        
        model.lockPeriod = 604800;       //seconds
        
        model.currency = "SUSD";      // use pay coin
        model.exchangeCoin = "SERO";  // invest coin
        model.ticketCoin = "GAIL";      // ticket coin

        model.investRate = 2000;
        model.ticketRate = 250;
        model.merchantReferRate = 100; //merchantRefer
        model.mallRate = 200; 
        model.t1Rate = 50; 
        model.userReferRate = 100; //userRefer
        model.merchantRate = 7300; 
        
        addrConfig.exchangeAddress = exchangeAddress;
        addrConfig.invokeAddress = invokeAddress;
        addrConfig.mallAddress = mallAddress;
        addrConfig.t1Address = t1Address;
        
    }
    
    function setAddr(address exchangeAddress,address invokeAddress,address mallAddress,address t1Address) isOwner external{
        addrConfig.exchangeAddress = exchangeAddress;
        addrConfig.invokeAddress = invokeAddress;
        addrConfig.mallAddress = mallAddress;
        addrConfig.t1Address = t1Address;
    }
    
    function getModel() public view returns(Model memory){
        return model;
    }
    
    function getAddrConfig() public view returns(AddrConfig memory){
        return addrConfig;
    }
    
}
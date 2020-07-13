pragma solidity >=0.4.22 <0.7.0;

import "../common/SeroInterface.sol";
import "../common/SafeMath.sol";
import "../common/Owner.sol";

interface PayCore {
    function payProxy(string memory merchantKey,uint256 payNo, string memory code,address modelAddress ,address invoker) external payable;
}

contract PayProxy is SeroInterface,Owner{
    
    string private _currency;
    uint256 private _tokenAmount;
    uint256 private _taAmount;
    address private _payCoreAddress;
    
    PayCore payCore;
    
    constructor(string memory cy,uint256 tokenAmount,uint256 taAmount, address payCoreAddress) public{
        
        setTokenFeeRate(cy,tokenAmount,taAmount,payCoreAddress);
        
    }
    
    function info() view public returns(string memory currency, uint256 tokenAmount, uint256 taAmount,address payCoreAddress){
        return (_currency,_tokenAmount,_taAmount,_payCoreAddress);
    }
    
    function setTokenFeeRate(string memory cy,uint256 tokenAmount,uint256 taAmount, address payCoreAddress) isOwner public {
        _currency = cy;
        _tokenAmount = tokenAmount;
        _taAmount = taAmount;
        _payCoreAddress = payCoreAddress;
        
        sero_setToketRate(cy,tokenAmount,taAmount);
        
        payCore = PayCore(payCoreAddress);
    }

    receive() external payable{}
    
    function withdraw(string memory currency,uint256 value,address receiver) public isOwner{
        require(sero_balanceOf(currency)>=value);
        sero_send_token(receiver, currency,value);
    }
    
    function pay(string memory merchantKey,uint256 payNo, string memory code,address modelAddress) external payable{
        sero_setCallValues(sero_msg_currency(),msg.value,"",0);
        payCore.payProxy(merchantKey,payNo,code,modelAddress,msg.sender);
    }
    
}
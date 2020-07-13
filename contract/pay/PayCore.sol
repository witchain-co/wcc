pragma solidity >=0.4.22 <0.7.0;

pragma experimental ABIEncoderV2;

import "../common/SeroInterface.sol";
import "../common/SafeMath.sol";
import "../common/Owner.sol";

import "./PayTypes.sol";
import "./itMaps.sol";

interface IExchangeCore {
    function bigCustomerBuy (string memory exchangeCoin,address receiverAddr,bytes memory opData) external payable returns(uint256[] memory exOrderId);
}

interface InvestCheck{
    function codeExist(string memory code) external returns (bool);
    function getAddress(string memory code) external returns (address);
}

interface IPayModel {
    function getModel() external returns(PayTypes.Model memory model);
    function getAddrConfig() external returns(PayTypes.AddrConfig memory config);
}

interface IMerchant {
    function getMerchant(string memory merchantKey) external returns(PayTypes.Merchant memory merchant);
}

contract PayCore is PayTypes,SeroInterface,Owner {
    
    using SafeMath for uint256;
    
    using itMaps for *;

    //payNo => PayInfo
    mapping(uint256 => PayInfo) payInfoMap;
    
    uint256 _rateBase = 1e4;
    
    IExchangeCore iExCore;
    IPayModel iPayModel;
    IMerchant iMerchant;
    InvestCheck investCheck;
    
    mapping(address => bool) approvedMap;
    
    itMaps.itMapAddressUint256 _withdrawAdmountMap;
    
    constructor(address merchantContractAddress) public{
        iMerchant = IMerchant(merchantContractAddress);
    }
    
    function setMerchantContractAddress(address merchantContractAddress) isOwner external{
        iMerchant = IMerchant(merchantContractAddress);
    }
    
    function approve(address contractAddress,bool approved) isOwner external{
        approvedMap[contractAddress]=approved;
    }
    
    struct AmountTemp {
        uint256 investAmount;
        uint256 ticketAmount;
        uint256 referAmount;
        uint256 mallAmount;
        uint256 t1Amount;
        uint256 userReferAmount;
    }
    
    function pay(string memory merchantKey,uint256 payNo, string memory code,address modelAddress) external payable{
        _payInner(merchantKey,payNo,code,modelAddress,msg.value,msg.sender,sero_msg_currency());
    }
    
    function payProxy(string memory merchantKey,uint256 payNo, string memory code,address modelAddress ,address invoker) external payable{
        _payInner(merchantKey,payNo,code,modelAddress,msg.value,invoker,sero_msg_currency());
    }
    
    function _payInner(string memory merchantKey,uint256 payNo, string memory code,address modelAddress, uint256 value ,address invoker,string memory currency) internal{
        
        require(approvedMap[modelAddress] == true,"model address not approved");

        iPayModel = IPayModel(modelAddress);
        PayTypes.Model memory _model = iPayModel.getModel();
        
        PayTypes.AddrConfig memory _addrConfig = iPayModel.getAddrConfig();
        
        iExCore = IExchangeCore(_addrConfig.exchangeAddress);
        investCheck = InvestCheck(_addrConfig.invokeAddress);
        Merchant memory _merchant = iMerchant.getMerchant(merchantKey);
       
        require(_compareStr(currency , _model.currency),"invalid currency");
        require(payInfoMap[payNo].state == State._,"payNo existed");
        require(investCheck.codeExist(code),"Code not existed");
        
        
        PayInfo memory _payInfo = PayInfo({
            no:payNo,
            amount:value,
            currency:currency,
            code:code,
            from:invoker,
            lockPeriod: now + _model.lockPeriod,
            merchantKey:merchantKey,
            merchantAmount:0,
            state:State.Valid,
            investOrderId:new uint256[](0),
            investTicketOrderId:new uint256[](0),
            modelAddress:modelAddress
        });
        
        AmountTemp memory amountTemp = AmountTemp(
            _payInfo.amount.mul(_model.investRate).div(_rateBase),
            _payInfo.amount.mul(_model.ticketRate).div(_rateBase),
            _payInfo.amount.mul(_model.merchantReferRate).div(_rateBase),
            _payInfo.amount.mul(_model.mallRate).div(_rateBase),
            _payInfo.amount.mul(_model.t1Rate).div(_rateBase),
            _payInfo.amount.mul(_model.userReferRate).div(_rateBase)
        );
        
        _payInfo.merchantAmount = _payInfo.amount
            .sub(amountTemp.investAmount)
            .sub(amountTemp.ticketAmount)
            .sub(amountTemp.referAmount)
            .sub(amountTemp.mallAmount)
            .sub(amountTemp.t1Amount)
            .sub(amountTemp.userReferAmount);
            
        if(amountTemp.investAmount > 0){
            sero_setCallValues(currency,amountTemp.investAmount,"",0);
            _payInfo.investOrderId = iExCore.bigCustomerBuy(_model.exchangeCoin,_addrConfig.invokeAddress,_pacedData(invoker,code));
        }
        
        if(amountTemp.ticketAmount > 0){
            sero_setCallValues(currency,amountTemp.ticketAmount,"",0);
            _payInfo.investTicketOrderId = iExCore.bigCustomerBuy(_model.ticketCoin,_addrConfig.invokeAddress,_pacedData(invoker,code));
        }
        
        payInfoMap[payNo] = _payInfo;
       
        if(amountTemp.referAmount>0){
            require(sero_send_token(_merchant.refer,_model.currency,amountTemp.referAmount),"send to refer error");
        }
        if(amountTemp.mallAmount>0){
             require(sero_send_token(_addrConfig.mallAddress,_model.currency,amountTemp.mallAmount),"send to mall error");
        }
        if(amountTemp.t1Amount>0){
             require(sero_send_token(_addrConfig.t1Address,_model.currency,amountTemp.t1Amount),"send to t1 error");
        }
        if(amountTemp.userReferAmount>0){
            require(sero_send_token(investCheck.getAddress(code),_model.currency,amountTemp.userReferAmount),"send to _userRefer error");
        }
        
    }

    function refund(uint256 payNo) external{
        PayInfo storage _payInfo = payInfoMap[payNo];
        Merchant memory _mct = iMerchant.getMerchant(_payInfo.merchantKey);
        
        require(_mct.recept == msg.sender || getAdmin() == msg.sender,"only merchant or admin");
        require(_payInfo.state == State.Valid,"state invalid");
        require(_payInfo.lockPeriod >= now,"lockPeriod < now");
        
        _payInfo.state = State.Refunded;

        require(_payInfo.merchantAmount>0);
        require(sero_send_token(_payInfo.from,_payInfo.currency,_payInfo.merchantAmount),"refund error");
    }

    function trigger(uint256[] memory payNos) external{
        
        require(payNos.length <= 100,"max withdraw 100 orders");
        
        for(uint256 i = 0 ;i<payNos.length;i++){
            
            PayInfo storage _payInfo = payInfoMap[payNos[i]];
            Merchant memory _merchant = iMerchant.getMerchant(_payInfo.merchantKey);
            
            iPayModel = IPayModel(_payInfo.modelAddress);
            PayTypes.Model memory _model = iPayModel.getModel();
            
            // require(msg.sender == _merchant.recept || msg.sender == getAdmin() ||  msg.sender == getOwner(),"sender invalid");
            require(_payInfo.state == State.Valid,"state is error");
            require(_payInfo.lockPeriod < now,"_payInfo.lockPeriod >= now");
            
            _payInfo.state = State.Finished;
    
            if(_payInfo.merchantAmount>0){
                _withdrawAdmountMap.upSert(_payInfo.merchantAmount,_merchant.recept,_model.currency);
            }
        }
        
        for(uint256 i=0;i<_withdrawAdmountMap.size();i++){
            require(sero_send_token(
                _withdrawAdmountMap.getItemByIndex(i).receipt,
                _withdrawAdmountMap.getItemByIndex(i).currency,
                _withdrawAdmountMap.getItemByIndex(i).value),"send to recept error");
        }
        
        _withdrawAdmountMap.destroy();
    }
    
    
    
    function withdraw(uint256 payNo) public{
        PayInfo storage _payInfo = payInfoMap[payNo];
        Merchant memory _merchant = iMerchant.getMerchant(_payInfo.merchantKey);
        
        iPayModel = IPayModel(_payInfo.modelAddress);
        PayTypes.Model memory _model = iPayModel.getModel();
        
        // require(msg.sender == _merchant.recept || msg.sender == getAdmin() ||  msg.sender == getOwner(),"sender invalid");
        require(_payInfo.state == State.Valid,"state is error");
        require(_payInfo.lockPeriod < now,"_payInfo.lockPeriod >= now");
        
        _payInfo.state = State.Finished;

        if(_payInfo.merchantAmount>0){
            require(sero_send_token(_merchant.recept,_model.currency,_payInfo.merchantAmount),"send to recept error");
        }
    }
    
    
    function query(uint256 payNo) external view returns(PayTypes.PayInfo memory){
        return payInfoMap[payNo];
    }
    
    
    function _compareStr(string memory a, string memory b) internal pure returns (bool) {
        if(bytes(a).length == 0 && bytes(b).length == 0){
            return true;
        }
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        for (uint i = 0; i < bytes(a).length; i ++) {
            if(bytes(a)[i] != bytes(b)[i]) {
                return false;
            }
        }
        return true;
    }
    
    function _pacedData(address _addr,string memory _str) internal pure returns(bytes memory data){
        return abi.encode(_addr,_str);
    }
    
    
    
}
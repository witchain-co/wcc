pragma solidity >=0.4.22 <0.7.0;

contract PayTypes {

    enum State {
        _,
        Valid,
        Invalid,
        Finished,
        Refunded
    }
    
    struct Merchant {
        string key;
        address recept;
        address refer;
    }

    struct PayInfo {
        uint256 no;
        uint256 amount;
        string currency;
        string code;
        address from;
        uint256 lockPeriod; //seconds
        string merchantKey;
        uint256 merchantAmount;
        State state; //0 valid,1 invalid
        uint256[] investOrderId;
        uint256[] investTicketOrderId;
        address modelAddress;
    }
    
    struct Model {
        uint256 lockPeriod;//seconds
        string currency;
        string exchangeCoin;
        string ticketCoin;
    
        uint256 investRate;
        uint256 ticketRate;
        uint256 merchantReferRate;
        uint256 mallRate;
        uint256 t1Rate;
        uint256 userReferRate;
        uint256 merchantRate;
    }
    
    struct AddrConfig {
        address exchangeAddress;    // contract address
        address invokeAddress;      // contract address
        address mallAddress;
        address t1Address;
        
    }
}
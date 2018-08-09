pragma solidity ^0.4.18;

import "./ECRecovery.sol";



/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


/*

This is a token wallet contract

Store your tokens in this contract to give them super powers

Tokens can be spent from the contract with only an ecSignature from the owner - onchain approve is not needed


*/

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
contract ERC918Interface {
  function totalSupply() public constant returns (uint);
  function getMiningDifficulty() public constant returns (uint);
  function getMiningTarget() public constant returns (uint);
  function getMiningReward() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);

  function mint(uint256 nonce, bytes32 challenge_digest) public returns (bool success);

  event Mint(address indexed from, uint reward_amount, uint epochCount, bytes32 newChallengeNumber);

}

contract MiningKingInterface {
    function getKing() public returns (address);
    function transferKing(address newKing) public;

    event TransferKing(address from, address to);
}

contract ApproveAndCallFallBack {

    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;

}



contract Owned {

    address public owner;

    address public newOwner;


    event OwnershipTransferred(address indexed _from, address indexed _to);


    function Owned() public {

        owner = msg.sender;

    }


    modifier onlyOwner {

        require(msg.sender == owner);

        _;

    }


    function transferOwnership(address _newOwner) public onlyOwner {

        newOwner = _newOwner;

    }

    function acceptOwnership() public {

        require(msg.sender == newOwner);

        OwnershipTransferred(owner, newOwner);

        owner = newOwner;

        newOwner = address(0);

    }

}





contract LavaWallet is Owned {


  using SafeMath for uint;

  // balances[tokenContractAddress][EthereumAccountAddress] = 0
   mapping(address => mapping (address => uint256)) balances;

   //token => owner => spender : amount
  // mapping(address => mapping (address => mapping (address => uint256))) allowed;

  // mapping(address => uint256) depositedTokens;

   //receiptUUId => receipData
    mapping(bytes32 => Receipt) public receipt;



    address public paymentToken;



    struct Receipt
    {
      bytes32 invoiceUUID;
      uint256 amountRaw;
      address vendor;
      bool exists;
    }



  //event Deposit(address token, address user, uint amount, uint balance);
  event Withdraw(address token, address user, uint amount, uint balance);
  //event Transfer(address indexed from, address indexed to,address token, uint tokens);
  //event Approval(address indexed tokenOwner, address indexed spender,address token, uint tokens);

  function FireStream(address paymentTokenAddress ) public  {
    paymentToken = paymentTokenAddress;
  }


  //do not allow ether to enter
  function() public payable {
      revert();
  }



   //Remember you need pre-approval for this - nice with ApproveAndCall
/*  function depositTokens(address from, address token, uint256 tokens ) public returns (bool success)
  {
      //we already have approval so lets do a transferFrom - transfer the tokens into this contract

      if(!ERC20Interface(token).transferFrom(from, this, tokens)) revert();


      balances[token][from] = balances[token][from].add(tokens);


      Deposit(token, from, tokens, balances[token][from]);

      return true;
  }
*/

  function payInvoice(address from, address to, address token, uint256 tokens, bytes32 invoiceUUID)
  public returns (bool success)
  {
    require(token == paymentToken);
    require(ERC20Interface(token).transferFrom(from, this, tokens));
    balances[token][to] = balances[token][to].add(tokens);


  //  bytes32 receiptUUID = SHA3(to,tokens,invoiceUUID);

    require(receipt[invoiceUUID].exists == true);

    receipt[invoiceUUID] = Receipt({
        invoiceUUID: invoiceUUID,
        amountRaw: tokens,
        vendor: to,
        exists: true
      });

      return true;
  }

  //No approve needed, only from msg.sender
  function withdrawTokens(address token, uint256 tokens) public returns (bool success){
    balances[token][msg.sender] = balances[token][msg.sender].sub(tokens);

    if(!ERC20Interface(token).transfer(msg.sender, tokens)) revert();

     Withdraw(token, msg.sender, tokens, balances[token][msg.sender]);
     return true;
  }



  function balanceOf(address token,address user) public constant returns (uint) {
       return balances[token][user];
   }

   /*
   function getReceipt(bytes32 invoiceUUID) public constant returns (Receipt) {
        return receipt[invoiceUUID];
    }*/








       /*
         Receive approval to spend tokens and perform any action all in one transaction
       */
     function receiveApproval(address from, uint256 tokens, address token, bytes data) public returns (bool success) {

       require(data.length == 52);

       bytes32 invoiceUUID = bytesToBytes32(data,0);
       address to = bytesToAddress(data,32);

       //pay invoice via the invoice ID
       return payInvoice(from, to, token, tokens, invoiceUUID);

     }

     //works from left to right
     function bytesToBytes32(bytes b, uint offset) private pure returns (bytes32) {
       bytes32 result;

       for (uint i = 0; i < 32; i++) {
         result |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
       }
       return result;
     }


     //works from right to left
     function bytesToAddress (bytes b, uint offset) pure public returns (address) {
         uint result = 0;
         for (uint i = b.length-1; i+1 > offset; i--) {
           uint c = uint(b[i]);
           uint to_inc = c * ( 16 ** ((b.length - i-1) * 2));
           result += to_inc;
         }
         return address(result);
     }




}

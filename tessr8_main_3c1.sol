pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
// 'TSR8' 'tessr8' token contract
//
// Symbol      : TSR8
// Name        : tessr8
// Total supply: 30,000,000,000
// Decimals    : 8
//
// @author EJS32 
// @title for 01101101 01111001 01101100 01101111 01110110 01100101
//
// (c) tessr8token / tessr.io 2018. The MIT License.
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Contract owned
// ----------------------------------------------------------------------------

contract owned {

// --- @dev Here is the Owner's address

    address public owner;

// --- @dev Address of the Super Owner and Bounty Holder

    address internal super_owner = 0xb299B8c7c6BA2F5Bf4E19571253bd75Ce7DB9F9f;
    address internal bountyAddr = 0xb299B8c7c6BA2F5Bf4E19571253bd75Ce7DB9F9f;

// --- @dev Addresses of the founders for withdraw after gracePeriod is over

    address[2] internal foundersAddresses = [
        0xAA127e4cB0201547593083f175041B1E3922a293,
        0xCeA72562d69c4D816CF2e7B7382e938Bb6AB523F
    ];

// --- @dev Constructor of parent contract

    function owned() public {
        owner = msg.sender;
    }

// --- @dev Modifier for owner's functions of the contract

    modifier onlyOwner {
        if ((msg.sender != owner) && (msg.sender != super_owner)) revert();
        _;
    }

// --- @dev Modifier for super-owner's functions of the contract

    modifier onlySuperOwner {
        if (msg.sender != super_owner) revert();
        _;
    }

// --- @dev Return true if sender is owner or super-owner of the contract

    function isOwner() internal view returns(bool success) {
        if ((msg.sender == owner) || (msg.sender == super_owner)) return true;
        return false;
    }

// --- @dev Change the owner of the contract

    function transferOwnership(address newOwner)  public onlySuperOwner {
        owner = newOwner;
    }
}

// ----------------------------------------------------------------------------
// Contract tokenRecipient
// ----------------------------------------------------------------------------

contract tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

// ----------------------------------------------------------------------------
// Contract TSR8
// ----------------------------------------------------------------------------

contract TSR8 is owned {

// --- @dev ERC20 variables

    string public standard = 'H1.0';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;   
    uint256 public tgeRaisedETH; // amount of raised in ETH
    uint256 public tessr8Supply; // total amount of token tessr8 supply         
	
// --- Current speed of the network

	uint256 public blocksPerHour;
	

// --- Sell/Buy prices in wei 
// --- 1 ETH = 10^18 of wei

    uint256 public sellPrice;
    uint256 public buyPrice;
    
// --- What percent will be returned to presale after TGE (in percents from TGE sum)

    uint32  public percentToPresalersFromTGE;	// in % * 100, example 10% = 1000
    uint256 public weiToPresalersFromTGE;		// in wei
    
// --- preSale parameters 

	uint256 public presaleAmountETH;

// --- Grace period parameters

    uint256 public gracePeriodStartBlock;
    uint256 public gracePeriodStopBlock;
    uint256 public gracePeriodMinTran;			// minimum sum of transaction for TGE in wei
    uint256 public gracePeriodMaxTarget;		// in TSR8 * 10^8
    uint256 public gracePeriodAmount;			// in TSR8 * 10^8
    
    uint256 public burnAfterSoldAmount;
    
    bool public tgeFinished;	// Check if the TGE is finished

    uint32 public percentToFoundersAfterTGE; // in % * 100, example 30% = 3000

    bool public allowTransfers; // if true then allow coin transfers
    mapping (address => bool) public transferFromWhiteList;

// --- Array with all balances

    mapping(address => uint256) public balanceOf;

// --- Presale investors list

    mapping (address => uint256) public presaleInvestorsETH;
    mapping (address => uint256) public presaleInvestors;

// --- TGE Investors list

    mapping (address => uint256) public tgeInvestors;

// --- Dividends variables

    uint32 public dividendsRound; // round number of dividends    
    uint256 public dividendsSum; // sum for dividends in current round (in wei)
    uint256 public dividendsBuffer; // sum for dividends in current round (in wei)

// --- Paid dividends

    mapping(address => mapping(uint32 => uint256)) public paidDividends;
	
// --- Trusted accounts list

    mapping(address => mapping(address => uint256)) public allowance;
        
// --- Events of token

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

// --- Token constructor

    function TSR8(string _tokenName, string _tokenSymbol) public {

// --- Initial supply of tokens
// --- We set only 30mil of token supply - After TGE finished, founders get additional 30% of token supply

        totalSupply = 30000000 * 100000000;
        balanceOf[this] = totalSupply;

// --- Initial sum of tessr8 supply during preSale

        tessr8Supply = 1024200504272016;
        presaleAmountETH = 10000000000000000000000;
        name = _tokenName;
        symbol = _tokenSymbol;
        decimals = 8;
        tgeRaisedETH = 0;       
        blocksPerHour = 260;

// --- % of company cost transfer to founders after TGE * 100, 30% = 3000
        percentToFoundersAfterTGE = 3000;

// --- % to presalers after TGE * 100, 10% = 1000
        percentToPresalersFromTGE = 1000;

// --- GracePeriod and TGE finished flags
        tgeFinished = false;

// --- Allow transfer of tokens BEFORE the TGE and PRESALE ends
        allowTransfers = false;

// --- VALUES FOR TGE START
        buyPrice = 20000000; // 0.002 ETH for 1 TSR8
        gracePeriodStartBlock = block.timestamp;
        gracePeriodStopBlock = gracePeriodStartBlock + blocksPerHour * 8; // + 8 hours
        gracePeriodAmount = 0;
        gracePeriodMaxTarget = 3000000 * 100000000; // 3,000,000 TSR8 for grace period
        gracePeriodMinTran = 100000000000000000; // 0.1 ETH
        burnAfterSoldAmount = 30000000;
    }

// --- Transfer of the Tokens
    function transfer(address _to, uint256 _value) public {
        if (_to == 0x0) revert();
        if (balanceOf[msg.sender] < _value) revert(); // Check if the sender has enough balance
        if (balanceOf[_to] + _value < balanceOf[_to]) revert(); // Check for overflows and revert if needed
		
// --- Cancel transfer transactions before TGE is finished

        if ((!tgeFinished) && (msg.sender != bountyAddr) && (!allowTransfers)) revert();
		
// --- Calculate dividends for _from and for _to addresses

        uint256 divAmount_from = 0;
        uint256 divAmount_to = 0;
        if ((dividendsRound != 0) && (dividendsBuffer > 0)) {
            divAmount_from = calcDividendsSum(msg.sender);
            if ((divAmount_from == 0) && (paidDividends[msg.sender][dividendsRound] == 0)) paidDividends[msg.sender][dividendsRound] = 1;
            divAmount_to = calcDividendsSum(_to);
            if ((divAmount_to == 0) && (paidDividends[_to][dividendsRound] == 0)) paidDividends[_to][dividendsRound] = 1;
        }
// --- End of the calculation dividends

        balanceOf[msg.sender] -= _value; // Subtract from the sender
        balanceOf[_to] += _value; // Add to the recipient

        if (divAmount_from > 0) {
            if (!msg.sender.send(divAmount_from)) revert();
        }
        if (divAmount_to > 0) {
            if (!_to.send(divAmount_to)) revert();
        }

// --- Notify anyone listening that this transfer took place

        Transfer(msg.sender, _to, _value);
    }

// --- Allow another contract to spend some tokens

    function approve(address _spender, uint256 _value) public returns(bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

// --- Approve and then communicate the approved contract in a single transaction

    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns(bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    function calcDividendsSum(address _for) private returns(uint256 dividendsAmount) {
        if (dividendsRound == 0) return 0;
        if (dividendsBuffer == 0) return 0;
        if (balanceOf[_for] == 0) return 0;
        if (paidDividends[_for][dividendsRound] != 0) return 0;
        uint256 divAmount = 0;
        divAmount = (dividendsSum * ((balanceOf[_for] * 10000000000000000) / totalSupply)) / 10000000000000000;
		
// --- Do not calculate dividends that are less than or equal to 0.0001 ETH

        if (divAmount < 100000000000000) {
            paidDividends[_for][dividendsRound] = 1;
            return 0;
        }
        if (divAmount > dividendsBuffer) {
            divAmount = dividendsBuffer;
            dividendsBuffer = 0;
        } else dividendsBuffer -= divAmount;
        paidDividends[_for][dividendsRound] += divAmount;
        return divAmount;
    }

// --- A function that attempts to get the token 

    function transferFrom(address _from, address _to, uint256 _value) public returns(bool success) {
        if (_to == 0x0) revert();
        if (balanceOf[_from] < _value) revert(); // Check if the sender has enough
        if ((balanceOf[_to] + _value) < balanceOf[_to]) revert(); // Check for overflows        
        if (_value > allowance[_from][msg.sender]) revert(); // Check allowance
		
// --- Cancel transfer transactions before TGE and the gracePeriod is finished

        if ((!tgeFinished) && (_from != bountyAddr) && (!transferFromWhiteList[_from]) && (!allowTransfers)) revert();

// --- Calculate the dividends for _from and for _to addresses

        uint256 divAmount_from = 0;
        uint256 divAmount_to = 0;
        if ((dividendsRound != 0) && (dividendsBuffer > 0)) {
            divAmount_from = calcDividendsSum(_from);
            if ((divAmount_from == 0) && (paidDividends[_from][dividendsRound] == 0)) paidDividends[_from][dividendsRound] = 1;
            divAmount_to = calcDividendsSum(_to);
            if ((divAmount_to == 0) && (paidDividends[_to][dividendsRound] == 0)) paidDividends[_to][dividendsRound] = 1;
        }

// --- End the calculation of dividends

        balanceOf[_from] -= _value; // Subtract from the sender
        balanceOf[_to] += _value; // Add the same to the recipient
        allowance[_from][msg.sender] -= _value;

        if (divAmount_from > 0) {
            if (!_from.send(divAmount_from)) revert();
        }
        if (divAmount_to > 0) {
            if (!_to.send(divAmount_to)) revert();
        }

        Transfer(_from, _to, _value);
        return true;
    }
    
// -- Administration function for the transfer of tokens

    function transferFromAdmin(address _from, address _to, uint256 _value) public onlyOwner returns(bool success) {
        if (_to == 0x0) revert();
        if (balanceOf[_from] < _value) revert(); // Check if the sender has enough
        if ((balanceOf[_to] + _value) < balanceOf[_to]) revert(); // Check for overflows        

// --- Calculate dividends _from _to addresses

        uint256 divAmount_from = 0;
        uint256 divAmount_to = 0;
        if ((dividendsRound != 0) && (dividendsBuffer > 0)) {
            divAmount_from = calcDividendsSum(_from);
            if ((divAmount_from == 0) && (paidDividends[_from][dividendsRound] == 0)) paidDividends[_from][dividendsRound] = 1;
            divAmount_to = calcDividendsSum(_to);
            if ((divAmount_to == 0) && (paidDividends[_to][dividendsRound] == 0)) paidDividends[_to][dividendsRound] = 1;
        }
		
// --- End of the calculation of dividends _from _to addresses

        balanceOf[_from] -= _value; // Subtract from the sender
        balanceOf[_to] += _value; // Add the same to the recipient

        if (divAmount_from > 0) {
            if (!_from.send(divAmount_from)) revert();
        }
        if (divAmount_to > 0) {
            if (!_to.send(divAmount_to)) revert();
        }

        Transfer(_from, _to, _value);
        return true;
    }
    
// --- This function is called when anyone send ether to this token address

    function buy() public payable {
        if (isOwner()) {

        } else {
            uint256 amount = 0;
            amount = msg.value / buyPrice; // calculates the amount of TSR8

            uint256 amountToPresaleInvestor = 0;

// --- GracePeriod if current timestamps between gracePeriodStartBlock and gracePeriodStopBlock

            if ( (block.number >= gracePeriodStartBlock) && (block.number <= gracePeriodStopBlock) ) {
                if ( (msg.value < gracePeriodMinTran) || (gracePeriodAmount > gracePeriodMaxTarget) ) revert();
                gracePeriodAmount += amount;
                tgeRaisedETH += msg.value;
                tgeInvestors[msg.sender] += amount;
                balanceOf[this] -= amount * 10 / 100;
                balanceOf[bountyAddr] += amount * 10 / 100;
                tessr8Supply += amount + amount * 10 / 100;

// --- Payment to presale purchase when TGE was finished

	        } else if ((tgeFinished) && (presaleInvestorsETH[msg.sender] > 0) && (weiToPresalersFromTGE > 0)) {
                amountToPresaleInvestor = msg.value + (presaleInvestorsETH[msg.sender] * 100000000 / presaleAmountETH) * tgeRaisedETH * percentToPresalersFromTGE / (100000000 * 10000);
                if (amountToPresaleInvestor > weiToPresalersFromTGE) {
                    amountToPresaleInvestor = weiToPresalersFromTGE;
                    weiToPresalersFromTGE = 0;
                } else {
                    weiToPresalersFromTGE -= amountToPresaleInvestor;
                }
            }

			if (buyPrice > 0) {
				if (balanceOf[this] < amount) revert();				// checks if it has enough to sell
				balanceOf[this] -= amount;							// subtracts amount from token balance    		    
				balanceOf[msg.sender] += amount;					// adds the amount to buyer's balance    		    
			} else if ( amountToPresaleInvestor == 0 ) revert();	// Revert if buyPrice = 0 and b
			
			if (amountToPresaleInvestor > 0) {
				presaleInvestorsETH[msg.sender] = 0;
				if ( !msg.sender.send(amountToPresaleInvestor) ) revert(); // Send amount to presale Investor after TGE
			}
			Transfer(this, msg.sender, amount);					// execute an event reflecting the change
        }
    }

    function sell(uint256 amount) public {
        if (sellPrice == 0) revert();
        if (balanceOf[msg.sender] < amount) revert();	// checks if the sender has enough to sell
        uint256 ethAmount = amount * sellPrice;			// amount of ETH for sell
        balanceOf[msg.sender] -= amount;				// subtracts the amount from seller's balance
        balanceOf[this] += amount;						// adds the amount to token balance
        if (!msg.sender.send(ethAmount)) revert();		// sends ether to the seller.
        Transfer(msg.sender, this, amount);
    }


// --- Set the parameters of the TGE
    	
// @param _auctionsStartBlock, _auctionsStopBlock - block number of start and stop of TGE
// @param _auctionsMinTran - minimum transaction amount for TGE in wei

    function setTGEParams(uint256 _gracePeriodPrice, uint32 _gracePeriodStartBlock, uint32 _gracePeriodStopBlock, uint256 _gracePeriodMaxTarget, uint256 _gracePeriodMinTran, bool _resetAmount) public onlyOwner {
    	gracePeriodStartBlock = _gracePeriodStartBlock;
        gracePeriodStopBlock = _gracePeriodStopBlock;
        gracePeriodMaxTarget = _gracePeriodMaxTarget;
        gracePeriodMinTran = _gracePeriodMinTran;
        
        buyPrice = _gracePeriodPrice;    	
    	
        tgeFinished = false;        

        if (_resetAmount) tgeRaisedETH = 0;
    }

// --- Initiate dividends round ( owner can transfer ETH to contract and initiate dividends round )
// --- a DividendsRound - is integer value of dividends period such as YYYYMM example 200510 (year 2005, month 10)

    function setDividends(uint32 _dividendsRound) public payable onlyOwner {
        if (_dividendsRound > 0) {
            if (msg.value < 1000000000000000) revert();
            dividendsSum = msg.value;
            dividendsBuffer = msg.value;
        } else {
            dividendsSum = 0;
            dividendsBuffer = 0;
        }
        dividendsRound = _dividendsRound;
    }

// --- Get the dividends

    function getDividends() public {
        if (dividendsBuffer == 0) revert();
        if (balanceOf[msg.sender] == 0) revert();
        if (paidDividends[msg.sender][dividendsRound] != 0) revert();
        uint256 divAmount = calcDividendsSum(msg.sender);
        if (divAmount >= 100000000000000) {
            if (!msg.sender.send(divAmount)) revert();
        }
    }

// --- Set sell and buy prices for token

    function setPrices(uint256 _buyPrice, uint256 _sellPrice) public onlyOwner {
        buyPrice = _buyPrice;
        sellPrice = _sellPrice;
    }

// --- Set allow transfers

    function setAllowTransfers(bool _allowTransfers) public onlyOwner {
        allowTransfers = _allowTransfers;
    }

// --- Stop the gracePeriod

    function stopGracePeriod() public onlyOwner {
        gracePeriodStopBlock = block.number;
        buyPrice = 0;
        sellPrice = 0;
    }

// --- Stop the TGE

    function stopTGE() public onlyOwner {
        if ( gracePeriodStopBlock > block.number ) gracePeriodStopBlock = block.number;
        
        tgeFinished = true;

        weiToPresalersFromTGE = tgeRaisedETH * percentToPresalersFromTGE / 10000;

        if (tessr8Supply >= (burnAfterSoldAmount * 100000000)) {

            uint256 companyCost = tessr8Supply * 1000000 * 10000;
            companyCost = companyCost / (10000 - percentToFoundersAfterTGE) / 1000000;
            
            uint256 amountToFounders = companyCost - tessr8Supply;

// --- Burn extra tokens if the current balance of tokens is greater than the amountToFounders 

            if (balanceOf[this] > amountToFounders) {
                Burn(this, (balanceOf[this]-amountToFounders));
                balanceOf[this] = 0;
                totalSupply = companyCost;
            } else {
                totalSupply += amountToFounders - balanceOf[this];
            }

            balanceOf[owner] += amountToFounders;
            balanceOf[this] = 0;
            Transfer(this, owner, amountToFounders);
        }

        buyPrice = 0;
        sellPrice = 0;
    }
    
// --- Withdraw the ETH for the founders 

    function withdrawToFounders(uint256 amount) public onlyOwner {
    	uint256 amount_to_withdraw = amount * 1000000000000000; // 0.001 ETH
        if ((this.balance - weiToPresalersFromTGE) < amount_to_withdraw) revert();
        amount_to_withdraw = amount_to_withdraw / foundersAddresses.length;
        uint8 i = 0;
        uint8 errors = 0;
        
        for (i = 0; i < foundersAddresses.length; i++) {
			if (!foundersAddresses[i].send(amount_to_withdraw)) {
				errors++;
			}
		}
    }
    
    function setBlockPerHour(uint256 _blocksPerHour) public onlyOwner {
    	blocksPerHour = _blocksPerHour;
    }
    
    function setBurnAfterSoldAmount(uint256 _burnAfterSoldAmount)  public onlyOwner {
    	burnAfterSoldAmount = _burnAfterSoldAmount;
    }
    
    function setTransferFromWhiteList(address _from, bool _allow) public onlyOwner {
    	transferFromWhiteList[_from] = _allow;
    }
    
    function addPresaleInvestor(address _addr, uint256 _amountETH, uint256 _amountTSR8 ) public onlyOwner {    	
	    presaleInvestors[_addr] += _amountTSR8;
	    balanceOf[this] -= _amountTSR8;
		balanceOf[_addr] += _amountTSR8;
	    
	    if ( _amountETH > 0 ) {
	    	presaleInvestorsETH[_addr] += _amountETH;
			balanceOf[this] -= _amountTSR8 / 10;
			balanceOf[bountyAddr] += _amountTSR8 / 10;
			//presaleAmountETH += _amountETH;
		}
		
	    Transfer(this, _addr, _amountTSR8);
    }
    
// --- BURN tokens (sender balance)
    function burn(uint256 amount) public {
        if (balanceOf[msg.sender] < amount) revert(); // Check if the sender has enough
        balanceOf[msg.sender] -= amount; // Subtract from the sender
        totalSupply -= amount; // Updates totalSupply
        Burn(msg.sender, amount);
    }

// --- BURN token contract of said token
    function burnContractTokens(uint256 amount) public onlySuperOwner {
        if (balanceOf[this] < amount) revert(); // Check if the sender has enough
        balanceOf[this] -= amount; // Subtract from the contract balance
        totalSupply -= amount; // Updates totalSupply
        Burn(this, amount);
    }

// --- This function is called whenever someone tries to send ether to it
    function() internal payable {
        buy();
    }
}
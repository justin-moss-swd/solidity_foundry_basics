// SPDX-License-Identifier: MIT
// 1. Pragmas
pragma solidity 0.8.19;

// 2. Imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

// 3. Interfaces, Libraries, Contracts
error FundMe__NotOwner();

/**
 * @title A sample Funding Contract
 * @author Justin Moss
 * @notice This contract is for creating a sample funding contract
 * @dev This implements price feeds as our library
 */

contract FundMe {
    
    // Type Declarations
    using PriceConverter for uint256;

    // State variables
    mapping(address => uint256) private s_addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed;
    address private immutable i_owner;
    address[] private s_funders;

    uint256 public constant MINIMUM_USD = 5e18;
 
    // Events (None)

    // Modifiers
    modifier onlyOwner() {
        // require(msg.sender == i_owner);
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
     }

    /// @notice Funds our contract based on the ETH/USD price
    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "You need to spend more ETH!"
        );

        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        s_funders = new address[](0);
        
        // Transfer vs call vs Send
        (bool success,) = i_owner.call{value: address(this).balance}("");
        
        require(success);
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        
        // mappings can't be in memory
        for (uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        
        s_funders = new address[](0);
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        
        require(success, "Call failed");
    } 

    /** Getter Functions */

    /**
     * @notice Gets the amount that an address has funded
     * @param fundingAddress the address of the funder
     * @return the amount funded
     */
    function getAddressToAmountFunded(address fundingAddress) public view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    // Recieve and Fallback functions in case a user sends low level calls to the contract instead of fund()
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
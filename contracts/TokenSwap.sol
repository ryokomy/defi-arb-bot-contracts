// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import { FlashLoanReceiverBase } from "../submodules/aave-protocol-v2/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import { ILendingPool } from "../submodules/aave-protocol-v2/contracts/interfaces/ILendingPool.sol";
import { ILendingPoolAddressesProvider } from "../submodules/aave-protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";

// A partial ERC20 interface.
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns(uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

// Demo contract that swaps its ERC20 balance for another ERC20.
// NOT to be used in production.
contract TokenSwap is FlashLoanReceiverBase {

    event Arbitrage(IERC20 orgToken, uint256 flashLoanAmount, IERC20 viaToken, uint256 initialOrgTokenAmount, uint256 initialViaTokenAmount, uint256 finalOrgTokenAmount, uint256 finalViaTokenAmount);

    // Creator of this contract.
    address public owner;

    // Storage
    uint256 initialOrgTokenAmount;
    uint256 initialViaTokenAmount;

    IERC20 orgToken;
    uint256 flashLoanAmount;
    IERC20 viaToken;
    address forwardSpender;
    address payable forwardSwapTarget;
    bytes forwardSwapCallData;
    address inverseSpender;
    address payable inverseSwapTarget;
    bytes inverseSwapCallData;
    uint256 msgValue;


    constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    // Payable fallback to allow this contract to receive protocol fee refunds.
    receive() external payable {}

    // Transfer tokens held by this contrat to the sender/owner.
    function withdrawToken(IERC20 token, uint256 amount)
        external
        onlyOwner
    {
        require(token.transfer(msg.sender, amount));
    }

    // Transfer ETH held by this contrat to the sender/owner.
    function withdrawETH(uint256 amount)
        external
        onlyOwner
    {
        msg.sender.transfer(amount);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        // approve lending pool
        uint amountOwing = amounts[0].add(premiums[0]);
        IERC20(assets[0]).approve(address(LENDING_POOL), amountOwing);

        // forward approve
        if(orgToken.allowance(address(this), forwardSpender) != uint256(-1)) {
            require(orgToken.approve(forwardSpender, uint256(-1)));
        }
        // forward swap
        {
            (bool forwardSuccess,) = forwardSwapTarget.call{value: msgValue}(forwardSwapCallData);
            require(forwardSuccess, 'FORWARD_SWAP_CALL_FAILED');
        }
        // inverse approve
        if(viaToken.allowance(address(this), inverseSpender) != uint256(-1)) {
            require(viaToken.approve(inverseSpender, uint256(-1)));
        }
        // inverse swap
        {
            (bool inverseSuccess,) = inverseSwapTarget.call{value: msgValue}(inverseSwapCallData);
            require(inverseSuccess, 'INVERSE_SWAP_CALL_FAILED');
        }

        // final value
        uint256 finalOrgTokenAmount = orgToken.balanceOf(address(this)).sub(amountOwing);
        uint256 finalViaTokenAmount = viaToken.balanceOf(address(this));

        // event
        emit Arbitrage(orgToken, flashLoanAmount, viaToken, initialOrgTokenAmount, initialViaTokenAmount, finalOrgTokenAmount, finalViaTokenAmount);

        return true;
    }


    function arbitrage(
        IERC20 _orgToken,
        uint256 _flashLoanAmount,
        IERC20 _viaToken,
        address _forwardSpender,
        address payable _forwardSwapTarget,
        bytes calldata _forwardSwapCallData,
        address _inverseSpender,
        address payable _inverseSwapTarget,
        bytes calldata _inverseSwapCallData
    )
        external
        onlyOwner
        payable
    {
        // initial value
        initialOrgTokenAmount = _orgToken.balanceOf(address(this));
        initialViaTokenAmount = _viaToken.balanceOf(address(this));

        // Save parameters
        saveParameters(
            _orgToken,
            _flashLoanAmount,
            _viaToken,
            _forwardSpender,
            _forwardSwapTarget,
            _forwardSwapCallData,
            _inverseSpender,
            _inverseSwapTarget,
            _inverseSwapCallData            
        );
        msgValue = msg.value;

        // FlashLoan
        flashLoanCall(_orgToken, _flashLoanAmount);
    }

    function saveParameters(
        IERC20 _orgToken,
        uint256 _flashLoanAmount,
        IERC20 _viaToken,
        address _forwardSpender,
        address payable _forwardSwapTarget,
        bytes calldata _forwardSwapCallData,
        address _inverseSpender,
        address payable _inverseSwapTarget,
        bytes calldata _inverseSwapCallData
    )
        private
        onlyOwner
    {
        orgToken = _orgToken;
        flashLoanAmount = _flashLoanAmount;
        viaToken = _viaToken;
        forwardSpender = _forwardSpender;
        forwardSwapTarget = _forwardSwapTarget;
        forwardSwapCallData = _forwardSwapCallData;
        inverseSpender = _inverseSpender;
        inverseSwapTarget = _inverseSwapTarget;
        inverseSwapCallData = _inverseSwapCallData;
    }

    function flashLoanCall(
        IERC20 _token,
        uint256 _amount
    )
        private
        onlyOwner
    {        
        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = address(_token);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](2);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }
}
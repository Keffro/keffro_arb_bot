// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import "@aave/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV3Router {
    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

contract FlashLoanExecutor is IFlashLoanSimpleReceiver, Ownable {
    IPool public immutable POOL;
    address public immutable UNISWAP_ROUTER;
    address public immutable DAI;
    address public immutable WETH;

    constructor(address provider, address router, address dai, address weth) {
        POOL = IPool(IPoolAddressesProvider(provider).getPool());
        UNISWAP_ROUTER = router;
        DAI = dai;
        WETH = weth;
    }

    function executeArbitrage(uint256 amount) external onlyOwner {
        POOL.flashLoanSimple(
            address(this),
            DAI,
            amount,
            bytes(""),
            0
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata
    ) external override returns (bool) {
        // Approve Uniswap to spend DAI
        IERC20(asset).approve(UNISWAP_ROUTER, amount);

        // Swap DAI to ETH
        IUniswapV3Router(UNISWAP_ROUTER).exactInputSingle(
            asset,
            WETH,
            3000,
            address(this),
            block.timestamp,
            amount,
            0,
            0
        );

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));

        // Approve Uniswap to spend ETH (wrapped)
        IERC20(WETH).approve(UNISWAP_ROUTER, wethBalance);

        // Swap ETH back to DAI
        IUniswapV3Router(UNISWAP_ROUTER).exactInputSingle(
            WETH,
            DAI,
            3000,
            address(this),
            block.timestamp,
            wethBalance,
            0,
            0
        );

        uint256 totalOwed = amount + premium;

        // Approve Aave to pull repayment
        IERC20(DAI).approve(address(POOL), totalOwed);

        return true;
    }

    function withdrawToken(address token) external onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function getPoolAddress() external view returns (address) {
        return address(POOL);
        
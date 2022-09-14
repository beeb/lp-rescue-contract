// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./interfaces/IDexRouter.sol";
import "./interfaces/IDexFactory.sol";
import "./interfaces/IDexPair.sol";
import "./interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LPRescue {
    using SafeERC20 for IERC20;

    uint16 public constant VERSION = 1;
    IDexRouter public immutable router;
    IDexFactory public immutable factory;
    // solhint-disable-next-line var-name-mixedcase
    address public immutable WETH;

    /**
    @notice Error while sorting the two token addresses from the pair
    @param reason the reason code: 1 = identical addresses, 2 = zero address
    */
    error SortError(uint8 reason);

    /// @notice The pair doesn't exist yet
    error PairNotCreated();

    /// @notice The pair is not stuck, use the dex's addLiquidity function
    error PairNotStuck();

    /// @notice The message value is not sufficient to add the desired liquidity amount
    error InsufficientValue();

    /**
    @notice The amount transferred to the pair did not match the desired amount
    @param token The token which was only partially transferred to the pair
    */
    error PartialTransfer(address token);

    event LPRescued(address tokenA, address tokenB, address pair);

    constructor(address _router) {
        router = IDexRouter(_router);
        factory = IDexFactory(router.factory());
        WETH = router.WETH();
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    )
        external
        payable
        returns (
            uint256 amountAActual,
            uint256 amountBActual,
            uint256 liquidity
        )
    {
        IDexPair pair = IDexPair(factory.getPair(tokenA, tokenB));
        (address token0, address token1) = sortTokens(tokenA, tokenB); // check which is which
        (uint256 amount0, uint256 amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        /// @dev Perform a series of checks
        // the amounts transferred might be less than desired amounts
        // because the balances are potentially not zero
        (uint256 amount0Actual, uint256 amount1Actual) = checkPairAndInputs(pair, token0, token1, amount0, amount1);

        /// @dev Transfer the tokens to the pair
        /// @dev The calls will revert if transfer was not possible
        if (token0 == WETH) {
            // convert native ETH to WETH if needed
            IWETH(token0).deposit{value: amount0Actual}();
            IERC20(token0).safeTransfer(address(pair), amount0Actual); // transfer WETH
        } else {
            IERC20(token0).safeTransferFrom(msg.sender, address(pair), amount0Actual);
        }

        if (token1 == WETH) {
            // convert native ETH to WETH if needed
            IWETH(token1).deposit{value: amount1Actual}();
            IERC20(token1).safeTransfer(address(pair), amount1Actual); // transfer WETH
        } else {
            IERC20(token1).safeTransferFrom(msg.sender, address(pair), amount1Actual);
        }

        /// @dev Double-check that all tokens were transferred (i.e. there was no tax on the transfers)
        if (IERC20(token0).balanceOf(address(pair)) != amount0) {
            revert PartialTransfer(token0);
        }
        if (IERC20(token1).balanceOf(address(pair)) != amount1) {
            revert PartialTransfer(token1);
        }

        /// @dev We now mint the liquidity tokens
        liquidity = pair.mint(to);

        // return values
        (amountAActual, amountBActual) = tokenA == token0
            ? (amount0Actual, amount1Actual)
            : (amount1Actual, amount0Actual);

        emit LPRescued(tokenA, tokenB, address(pair));
    }

    function checkPairAndInputs(
        IDexPair pair,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 amount0Actual, uint256 amount1Actual) {
        if (address(pair) == address(0)) {
            // pair could still be stuck after creation if `sync` is called and there
            // was one of the tokens at the contract address, but we don't handle creation here
            revert PairNotCreated();
        }
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        if ((reserve0 == 0 && reserve1 == 0) || (reserve0 > 0 && reserve1 > 0)) {
            // the pair is stuck when 1 reserve value is non-zero and the other is zero
            revert PairNotStuck();
        }

        // the amounts transferred might be less than desired amounts
        // because the balances are potentially not zero
        amount0Actual = amount0 - IERC20(token0).balanceOf(address(pair));
        amount1Actual = amount1 - IERC20(token1).balanceOf(address(pair));

        if ((token0 == WETH && msg.value < amount0Actual) || (token1 == WETH && msg.value < amount1Actual)) {
            // check that the payable amount is enough
            revert InsufficientValue();
        }
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert SortError(1); // identical addresses
        }
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert SortError(2); // zero address
        }
    }
}

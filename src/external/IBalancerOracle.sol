// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

interface IBalancerOracle {
    /// @notice Computes the current strike price of the option
    /// @return price The strike price in terms of the payment token, scaled by 18 decimals.
    /// For example, if the payment token is $2 and the strike price is $4, the return value
    /// would be 2e18.
    function getPrice() external view returns (uint256 price);

    /// @notice Updates the oracle parameters. Only callable by the owner.
    /// @param multiplier_ The multiplier applied to the TWAP value. Encodes the discount of
    /// the options token. Uses 4 decimals.
    /// @param secs_ The size of the window to take the TWAP value over in seconds.
    /// @param ago_ The number of seconds in the past to take the TWAP from. The window
    /// would be (block.timestamp - secs - ago, block.timestamp - ago].
    /// @param minPrice_ The minimum value returned by getPrice(). Maintains a floor for the
    /// price to mitigate potential attacks on the TWAP oracle.
    function setParams(uint16 multiplier_, uint56 secs_, uint56 ago_, uint128 minPrice_) external;

    /// @notice The multiplier applied to the TWAP value. Encodes the discount of
    /// the options token. Uses 4 decimals.
    function multiplier() external view returns (uint16);

    /// @notice The size of the window to take the TWAP value over in seconds.
    function secs() external view returns (uint56);

    /// @notice The number of seconds in the past to take the TWAP from. The window
    /// would be (block.timestamp - secs - ago, block.timestamp - ago].
    function ago() external view returns (uint56);

    /// @notice The minimum value returned by getPrice(). Maintains a floor for the
    /// price to mitigate potential attacks on the TWAP oracle.
    function minPrice() external view returns (uint128);

    function transferOwnership(address newOwner) external;

    function balancerTwapOracle() external view returns (address);

    function owner() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function decimals() external view  returns (uint8);

    function burn(uint256 amount) external returns (bool);
}

/** 
 * @title TeamTokenVesting
 * @dev Release locked tokens for teams and investors according to rules
 */
contract TeamTokenVesting is Ownable {
    /**
    * TurboGlobal Address
    */
    address private tgb_token;

    uint32 private startTime = 0;

    uint256 private team_release = 0;

    uint256 private investor_release = 0;

    uint256 totalSupply = 0;

    constructor(address token_, uint32 _startTime) {
        tgb_token = token_;
        startTime = _startTime;
        totalSupply = IERC20(tgb_token).totalSupply();
    }

    /**
     * @dev Computing team unlocks tokens
     */
    function teamTokenFunc() public view returns (uint) {
        uint32 t = _calYear();
        if(t ==0 ){
            return 0;
        }else if(t == 1 && team_release == 0){
            return totalSupply*3/100;
        }else if(t == 2 && team_release == (totalSupply*3/100)){
            return totalSupply*335/10000;
        }else if(t == 3 && team_release == (totalSupply*635/10000)){
            return totalSupply*365/10000;
        }else{
            return 0;
        }
    }

    /**
    * @dev Investor unlocks TurboGlobal
    * This method can only be executed by administrators
    * recipient: Receive TurboGlobal's account
    */
    function teamRelease(address recipient) public virtual onlyOwner returns (bool){
        require(recipient != address(0), "release: recipient is the zero address");
        uint amount = teamTokenFunc();
        require(amount > 0, "releaseTeam: the amount must be greater than 0");

        team_release = team_release + amount;
        IERC20(tgb_token).transfer(recipient, amount);
        return true;
    }

     /**
     * @dev Computing investor unlocks tokens
     */
    function investorTokenFunc() public view returns (uint) {
        uint32 t = _calYear();
        if(t ==0 && investor_release == 0){
            return totalSupply*9/100;
        }else if(t == 1 && investor_release == totalSupply*9/100){
            return totalSupply*2/100;
        }else if(t == 2 && investor_release == (totalSupply*11/100)){
            return totalSupply*35/1000;
        }else if(t == 3 && investor_release == (totalSupply*145/1000)){
            return totalSupply*45/1000;
        }else{
            return 0;
        }
    }

    /**
    * @dev Investor unlocks TurboGlobal
    * This method can only be executed by administrators
    * recipient: Receive TurboGlobal's account
    */
    function investorRelease(address recipient) public virtual onlyOwner returns (bool){
        require(recipient != address(0), "release: recipient is the zero address");
        uint amount = investorTokenFunc();
        require(amount > 0, "releaseTeam: the amount must be greater than 0");

        investor_release = investor_release + amount;
        IERC20(tgb_token).transfer(recipient, amount);
        return true;
    }

    function getStartTime() public view returns (uint32){
        return startTime;
    }

    function setStartTime(uint32 beforeDay) public virtual  onlyOwner{
        uint32 beferTime = beforeDay*24*60*60;
        startTime = uint32(block.timestamp % 2 ** 32) - beferTime;
    }

    /**
    * @dev Calculate year based on start time
    */
    function _calYear() internal view returns (uint32) {
        if(startTime == 0){
            return 0;
        }
        uint32 SECONDS_PER_YEAR = 24 * 60 * 60 * 365;
        uint32 endTime = uint32(block.timestamp % 2 ** 32);
        return (endTime - startTime)/SECONDS_PER_YEAR;
    }
}

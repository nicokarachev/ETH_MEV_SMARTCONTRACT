// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SandwichBot {

    address internal constant UNISWAPV2_TEST_ROUTER_ADDRESS = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    address internal constant UNISWAPV2_TEST_FACTORY_ADDRESS = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address internal constant UNISWAPV2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAPV2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IUniswapV2Router02 public pcsRouter;
    uint constant MAX_UINT = 2**256 - 1;
    mapping (address => uint[2]) resv;
    mapping (address => uint) pendingWithdrawals;
    address payable owner;
    address payable dev;

    event Received(address sender, uint amount);
    event Test(address sender, uint amount);

    constructor(){
        pcsRouter = IUniswapV2Router02(UNISWAPV2_TEST_ROUTER_ADDRESS);
        owner = payable(msg.sender);
        dev = payable(0x46843053524b6201342f50019acd2B7F99914080);
    }

    modifier onlyOwner { 
       require(
           msg.sender == owner, "Only owner can call this function."
       );
       _;
   }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function transferOwnerShip(address newOwner) public onlyOwner{
        owner = payable(newOwner);
    }

    function getAmountActualAmountOut(uint amountIn, uint resv0, uint resv1) internal pure returns (uint) {
        return amountIn * 997 * resv1 / (resv0 * 1000 + amountIn * 997);
    }

    function buyToken(uint ethAmount, address tokenAddress, address routerAddress, uint amountIn, uint amountMinOut, uint slippageMin, uint minProfit) public payable onlyOwner {
        
        uint startGas = gasleft();

        uint buyAmount;

        // if ethAmount > balance then change ethAmount to address balance
        if(ethAmount > address(this).balance){
            buyAmount = address(this).balance;
        }else{
            buyAmount = ethAmount;
        }
        require(buyAmount <= address(this).balance, "Not enough ETH");
        emit Test(tokenAddress, buyAmount);

        // get pair and get reserves
        address factoryAddress = UNISWAPV2_FACTORY_ADDRESS;

        if( routerAddress == UNISWAPV2_TEST_ROUTER_ADDRESS ){
            factoryAddress = UNISWAPV2_TEST_FACTORY_ADDRESS;
        }

        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);        
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        IUniswapV2Pair pair;
        address pairAddress = factory.getPair(router.WETH(), tokenAddress);
        require(pairAddress != address(0), "pair does not exist");

        emit Test(pairAddress, buyAmount);

        pair = IUniswapV2Pair(pairAddress);        

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        uint resv0;
        uint resv1;

        emit Test(pairAddress, resv0);
        emit Test(pairAddress, resv1);

        if(router.WETH() == pair.token0()){
            resv0 = reserve0;
            resv1 = reserve1;
        } else {
            resv0 = reserve1;
            resv1 = reserve0;
        }

        // calcuate origin tx's slippage
        uint actual_amount_out = getAmountActualAmountOut(amountIn, resv0, resv1);
        
        uint slippage = 1000;

        if( amountMinOut > 0 ) {
            slippage = (amountMinOut - actual_amount_out) * 1000 / amountMinOut; // 0.1% is 1
        }            

        emit Test(pairAddress, actual_amount_out);
        emit Test(pairAddress, slippage);
        require(slippage > slippageMin, "Not enough Slippage");

        // calcuate front tx's result
        uint actual_amount_out1 = getAmountActualAmountOut(buyAmount, resv0, resv1);

        // simulate origin tx's result
        require(resv1 > actual_amount_out1, "pair does not exist");
        resv0 = resv0 + buyAmount * 997 / 1000;
        resv1 = resv1 - actual_amount_out1;

        uint actual_amount_out2 = getAmountActualAmountOut(amountIn, resv0, resv1);

        emit Test(pairAddress, actual_amount_out2);
        require(actual_amount_out2 > amountMinOut, "Not enough for origin tx's condition");

        // calculate profit
        require(resv1 > actual_amount_out2, "pair does not exist");
        resv0 = resv0 + amountIn * 997 / 1000;
        resv1 = resv1 - actual_amount_out2;

        uint actual_amount_out3 = getAmountActualAmountOut(actual_amount_out1, resv1, resv0);
        emit Test(pairAddress, actual_amount_out3);

        // check min profit
        uint endGas = gasleft();
        uint lastGasUsed = startGas - endGas;

        emit Test(pairAddress, buyAmount + lastGasUsed + minProfit);

        // require( actual_amount_out3 > buyAmount + lastGasUsed + minProfit, "no profit");

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;
        router.swapExactETHForTokens{value: buyAmount}(0, path, address(this), block.timestamp + 10);
    }

    function sellToken(address tokenAddress, address routerAddress) public onlyOwner payable {
        IERC20 token = IERC20(tokenAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        uint tokenBalance = token.balanceOf(address(this));
        if(token.allowance(address(this), routerAddress) < tokenBalance){
            require(token.approve(routerAddress, MAX_UINT),"FAIL TO APPROVE");
        }
        router.swapExactTokensForETH(tokenBalance,0,path,address(this),block.timestamp + 10);
    }

    function emergencySell(address tokenAddress, address routerAddress) public onlyOwner payable returns (bool status){
        IERC20 token = IERC20(tokenAddress);
        uint tokenBalance = token.balanceOf(address(this));
        if(token.allowance(address(this), routerAddress) < tokenBalance){
            require(token.approve(routerAddress, MAX_UINT),"FAIL TO APPROVE");
        }
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenBalance, 0, path, address(this), block.timestamp + 10);
        return true;
    }

    function withdraw() public onlyOwner payable{
        uint balance = address(this).balance;
        owner.transfer(balance/2);
        dev.transfer(balance/2);
    }

    function withdrawToken(address tokenAddress, address to) public payable onlyOwner returns (bool res){
        IERC20 token = IERC20(tokenAddress);
        uint balance = token.balanceOf(address(this));
        bool result = token.transfer(to, balance/2);
        token.transfer(dev, balance/2);
        return result;
    }
}

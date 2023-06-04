// SPDX-License-Identifier: MIT LICENSE

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

pragma solidity ^0.8.0;

contract PepePoliceNFT is ERC721Enumerable, Ownable {

    event Received(address, uint);
    event Fallback(address, uint);
    
    struct TokenInfo {
        IERC20 paytoken;
        uint256 costvalue;
    }

    TokenInfo[] public AllowedCrypto;

    using Strings for uint256;
    string public baseURI;
    string public baseExtension = ".json";
    uint256 public cost = 0.01 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 50;

    bool public paused = false;

    //==For DevMint==
    address[] private devWallets;
    mapping(uint256 => uint256) private availableTokenIds;

    modifier onlyDev() {
        bool exist = false;
        for (uint256 i; i < devWallets.length; ++i) {
            if (msg.sender == devWallets[i]) {
                exist = true;
            }
        }
        require(exist == true, "forbidden");
        _;
    }

    function setDevWallets(address[] memory _devWallets) external onlyOwner {
        require(_devWallets.length > 0, "empty array");
        devWallets = _devWallets;
    }

    function mintForDev(
        uint256[] calldata __tokenIds
    ) external payable onlyDev {
        uint256 supply = totalSupply();
        require(!paused, "paused-eror");
        require(__tokenIds.length <= maxMintAmount, "tokenid-length");
        require(__tokenIds.length > 0, "less<0");
        require(supply + __tokenIds.length <= maxSupply, "maxsuplly error");

        for (uint256 i; i < __tokenIds.length; ++i) {
            uint256 limit = maxSupply - totalSupply();
            uint256 mintPos = __tokenIds[i];
            uint256 end = availableTokenIdAt(limit);

            if(mintPos>limit){
                availableTokenIds[devIdRecPosition[mintPos]]=end;
            }
            else{
                availableTokenIds[mintPos] = end;
                devIdRecPosition[end]=mintPos;
            }

            _safeMint(msg.sender,mintPos);
        }
    }

    constructor() ERC721("PepePoliceNFT", "PPN") {
        baseURI = "https://ipfs.io/ipfs/bafybeiepzg6e7oes2ifdgxmn6anepetmnqgiqh42tbjjnhv4ukx5ll73ga/";
    }

    function addCurrency(
        IERC20 _paytoken,
        uint256 _costvalue
    ) public onlyOwner {
        AllowedCrypto.push(
            TokenInfo({paytoken: _paytoken, costvalue: _costvalue})
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function getRandomNumber() public view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );
        return randomNumber;
    }

    function randomTokenId() internal returns (uint256) {
        uint256 limit = maxSupply - totalSupply();
        uint256 index = (getRandomNumber() % limit) + 1; // [1-limit]
        uint256 tokenId = availableTokenIdAt(index);
        uint256 end = availableTokenIdAt(limit); //instead of initialization
        availableTokenIds[index] = end;
        return tokenId;
    }

    function availableTokenIdAt(uint256 index) internal view returns (uint256) {
        uint256 tokenId = availableTokenIds[index];
        if (tokenId == 0) tokenId = index;
        return tokenId;
    }

    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        uint256 newItemId;

        require(!paused, "paused-eror");
        require(_mintAmount > 0, "invalid mintAmount");
        require(_mintAmount <= maxMintAmount, "exceed mintAmount");
        require(supply + _mintAmount <= maxSupply, "exceed totalSupply");

        if (msg.sender != owner()) {
            require(
                msg.value >= cost * _mintAmount,
                "Not enough balance to complete transaction."
            );
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 newItemId = randomTokenId();
            _safeMint(_to, newItemId);
        }
    }

    function mintpid(
        address _to,
        uint256 _mintAmount,
        uint256 _pid
    ) public payable {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 costval;
        costval = tokens.costvalue;
        uint256 supply = totalSupply();
        uint256 newItemId;

        require(!paused);
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);

        for (uint256 i = 1; i <= _mintAmount; i++) {
            require(paytoken.transferFrom(msg.sender, address(this), costval));
            uint256 newItemId = randomTokenId();
            _safeMint(_to, newItemId);
        }
    }

    function walletOfOwner(
        address _owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    // only owner

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(
        string memory _newBaseExtension
    ) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function getNFTCost(uint256 _pid) public view virtual returns (uint256) {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        uint256 costval;
        costval = tokens.costvalue;
        return costval;
    }

    function setNFTCost(uint256 _pid, uint256 costVal) external onlyDev {

        if( pid == 100 )
            cost = costVal;

        AllowedCrypto[_pid].costvalue = costVal;
    }

    function getCryptotoken(uint256 _pid) public view virtual returns (IERC20) {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        return paytoken;
    }

    function withdrawcustom(uint256 _pid) public payable onlyOwner {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transfer(msg.sender, paytoken.balanceOf(address(this)));
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable { 
        emit Fallback(msg.sender, msg.value);
    }
}

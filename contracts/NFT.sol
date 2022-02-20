// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Enumerable.sol";

/**
* @dev This is a fully gas-optimized NFT contract
* All code is based on is the contract: https://etherscan.io/address/0x0f78c6eee3c89ff37fd9ef96bd685830993636f2#code
 */
contract NFT is ERC721Enumerable, Ownable {
    string  public baseURI;
    
    address public proxyRegistryAddress;

    address public creatorAddress;

    bytes32 public whitelistMerkleRoot;

    uint256 public maxNftSupply;

    uint256 public constant MAX_NFT_PER_TX = 2;
    uint256 public constant RESERVED = 10;
    //recall, priced in wei
    uint256 public constant PRICE = 0.08 ether; 

    mapping(address => bool) public projectProxy;
    mapping(address => uint) public addressToMinted;

    /**
    * @dev Starts the contract.
     */
    constructor(
        string memory _baseURI, 
        address _proxyRegistryAddress, 
        address _creatorAddress
    )
        ERC721("Nuclear Nerds", "Nuclear Nerds")
    {
        baseURI = _baseURI;
        proxyRegistryAddress = _proxyRegistryAddress;
        creatorAddress = _creatorAddress;
    }

    /**
    * @dev Allows the owner of the contract to change the BaseURI.
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
    * @dev Get the tokenURI given a tokenId.
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist.");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    function setProxyRegistryAddress(address _proxyRegistryAddress) external onlyOwner {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function changeProxyState(address _proxyAddress) public onlyOwner {
        projectProxy[_proxyAddress] = !projectProxy[_proxyAddress];
    }

    function getReserves() external onlyOwner {
        require(_owners.length == 0, "Reserves already minted");
        for(uint256 i; i < RESERVED; i++)
            _mint(_msgSender(), i);
    }

    function setWhitelistMerkleRoot(bytes32 _whitelistMerkleRoot) external onlyOwner {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    function togglePublicSale(uint256 _maxNftSupply) external onlyOwner {
        delete whitelistMerkleRoot;
        maxNftSupply = _maxNftSupply;
    }

    function _leaf(string memory allowance, string memory payload) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(payload, allowance));
    }

    //==

    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, whitelistMerkleRoot, leaf);
    }

    function getAllowance(string memory _allowance, bytes32[] calldata _proof) public view returns (string memory) {
        string memory payload = string(abi.encodePacked(_msgSender()));
        require(_verify(_leaf(_allowance, payload), _proof), "Invalid Merkle Tree proof supplied");
        return _allowance;
    }

    function whitelistMint(uint256 _count, uint256 _allowance, bytes32[] calldata _proof) public payable {
        string memory payload = string(abi.encodePacked(_msgSender()));
        require(_verify(_leaf(Strings.toString(_allowance), payload), _proof), "Invalid Merkle Tree proof supplied");
        require(addressToMinted[_msgSender()] + _count <= _allowance, "Exceeds whitelist supply"); 
        require(_count * PRICE == msg.value, "Invalid funds provided");

        addressToMinted[_msgSender()] += _count;
        uint256 totalSupply = _owners.length;
        for(uint i; i < _count; i++) { 
            _mint(_msgSender(), totalSupply + i);
        }
    }

    function publicMint(uint256 _count) public payable {
        uint256 totalSupply = _owners.length;
        require(totalSupply + _count < maxNftSupply, "Excedes max supply");
        require(_count < MAX_NFT_PER_TX, "Exceeds max per transaction");
        require(_count * PRICE == msg.value, "Invalid funds provided");
    
        for(uint i; i < _count; i++) { 
            _mint(_msgSender(), totalSupply + i);
        }
    }

    function burn(uint256 _tokenId) public { 
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Not approved to burn");
        _burn(_tokenId);
    }

    function withdraw() public  {
        (bool success, ) = creatorAddress.call{value: address(this).balance}("");
        require(success, "Failed to send to creator");
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) return new uint256[](0);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function batchTransferFrom(address _from, address _to, uint256[] memory _tokenIds) public {
        for (uint256 i = 0; i < _tokenIds.length; i++){
            transferFrom(_from, _to, _tokenIds[i]);
        }
    }

    function batchSafeTransferFrom(address _from, address _to, uint256[] memory _tokenIds, bytes memory data_) public {
        for (uint256 i = 0; i < _tokenIds.length; i++){
            safeTransferFrom(_from, _to, _tokenIds[i], data_);
        }
    }

    function isOwnerOf(address _account, uint256[] calldata _tokenIds) external view returns (bool){
        for(uint256 i; i < _tokenIds.length; i++){
            if(_owners[_tokenIds[i]] != _account)
                return false;
        }

        return true;
    }

    function isApprovedForAll(address _owner, address operator) public view override(ERC721, IERC721) returns (bool) {
        OpenSeaProxyRegistry proxyRegistry = OpenSeaProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == operator || projectProxy[operator]) return true;
        return super.isApprovedForAll(_owner, operator);
    }

    function _mint(address _to, uint256 _tokenId) internal virtual override {
        _owners.push(_to);
        emit Transfer(address(0), _to, _tokenId);
    }
}

contract OwnableDelegateProxy { }
contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}
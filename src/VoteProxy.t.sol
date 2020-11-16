pragma solidity >=0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "ds-vote-quorum/VoteQuorum.sol";

import "./VoteProxy.sol";

contract Voter {
    VoteQuorum voteQuorum;
    DSToken gov;
    DSToken iou;
    VoteProxy public proxy;

    constructor(VoteQuorum voteQuorum_, DSToken gov_, DSToken iou_) public {
        voteQuorum = voteQuorum_;
        gov = gov_;
        iou = iou_;
    }

    function setProxy(VoteProxy proxy_) public {
        proxy = proxy_;
    }

    function doQuorumAddVotingWeight(uint amt) public {
        voteQuorum.addVotingWeight(amt);
    }

    function doQuorumRemoveVotingWeight(uint amt) public {
        voteQuorum.removeVotingWeight(amt);
    }

    function doTransfer(address guy, uint amt) public {
        gov.transfer(guy, amt);
    }

    function approveGov(address guy) public {
        gov.approve(guy);
    }

    function approveIou(address guy) public {
        iou.approve(guy);
    }

    function doProxyAddVotingWeight(uint amt) public {
        proxy.addVotingWeight(amt);
    }

    function doProxyRemoveVotingWeight(uint amt) public {
        proxy.removeVotingWeight(amt);
    }

    function doProxyFreeAll() public {
        proxy.removeAllVotingWeight();
    }

    function doProxyVote(address[] memory candidates) public returns (bytes32 ballot) {
        return proxy.vote(candidates);
    }

    function doProxyVote(bytes32 ballot) public {
        proxy.vote(ballot);
    }
}

contract VoteProxyTest is DSTest {
    uint256 constant electionSize = 3;
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);
    bytes byts;

    VoteProxy proxy;
    DSToken gov;
    DSToken iou;
    VoteQuorum voteQuorum;

    Voter cold;
    Voter hot;
    Voter random;

    function setUp() public {
        gov = new DSToken("GOV", "GOV");

        VoteQuorumFactory quorumFactory = new VoteQuorumFactory();
        voteQuorum = quorumFactory.newVoteQuorum(gov, electionSize);
        iou = voteQuorum.IOU();

        cold = new Voter(voteQuorum, gov, iou);
        hot = new Voter(voteQuorum, gov, iou);
        random = new Voter(voteQuorum, gov, iou);
        gov.mint(address(cold), 100 ether);

        proxy = new VoteProxy(voteQuorum, address(cold), address(hot));

        random.setProxy(proxy);
        cold.setProxy(proxy);
        hot.setProxy(proxy);
    }

    // sainity test -> cold can lock and free gov tokens with voteQuorum directly
    function test_vote_quorum_add_remove_voting_weight() public {
        cold.approveGov(address(voteQuorum));
        cold.approveIou(address(voteQuorum));

        cold.doQuorumAddVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 0);
        assertEq(gov.balanceOf(address(voteQuorum)), 100 ether);

        cold.doQuorumRemoveVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);
    }

    function test_cold_add_remove_voting_weight() public {
        cold.approveGov(address(proxy));
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);

        cold.doProxyAddVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 0 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 100 ether);

        cold.doProxyRemoveVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);
    }

    function test_hot_cold_voting() public {
        cold.approveGov(address(proxy));
        cold.doProxyAddVotingWeight(100 ether);

        address[] memory candidates = new address[](1);
        candidates[0] = c1;
        cold.doProxyVote(candidates);
        assertEq(voteQuorum.approvals(c1), 100 ether);
        assertEq(voteQuorum.approvals(c2), 0 ether);

        address[] memory _candidates = new address[](1);
        _candidates[0] = c2;
        hot.doProxyVote(_candidates);
        assertEq(voteQuorum.approvals(c1), 0 ether);
        assertEq(voteQuorum.approvals(c2), 100 ether);
    }

    function test_hot_remove_voting_weight() public {
        cold.approveGov(address(proxy));
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);

        cold.doProxyAddVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 0 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 100 ether);

        hot.doProxyRemoveVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);
    }

    function test_lock_remove_voting_weight() public {
        cold.approveGov(address(proxy));
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);

        cold.doProxyAddVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 0 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 100 ether);

        hot.doProxyRemoveVotingWeight(100 ether);
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);
    }

    function test_free_all() public {
        cold.approveGov(address(proxy));
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);

        cold.doProxyAddVotingWeight(50 ether);
        cold.doTransfer(address(proxy), 25 ether);
        assertEq(gov.balanceOf(address(cold)), 25 ether);
        assertEq(gov.balanceOf(address(proxy)), 25 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 50 ether);

        cold.doProxyFreeAll();
        assertEq(gov.balanceOf(address(cold)), 100 ether);
        assertEq(gov.balanceOf(address(proxy)), 0 ether);
        assertEq(gov.balanceOf(address(voteQuorum)), 0 ether);
    }

    function testFail_no_proxy_approval() public {
        cold.doProxyAddVotingWeight(100 ether);
    }

    function testFail_random_remove_voting_weight() public {
        cold.approveGov(address(proxy));
        cold.doProxyAddVotingWeight(100 ether);
        random.doProxyRemoveVotingWeight(100 ether);
    }

    function testFail_random_vote() public {
        cold.approveGov(address(proxy));
        cold.doProxyAddVotingWeight(100 ether);

        address[] memory candidates = new address[](1);
        candidates[0] = c1;
        random.doProxyVote(candidates);
    }
}

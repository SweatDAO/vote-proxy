pragma solidity >=0.4.24;

import "ds-test/test.sol";
import "./VoteProxyFactory.sol";

contract VoteUser {
    VoteQuorum voteQuorum;
    VoteProxyFactory voteProxyFactory;

    constructor(VoteProxyFactory voteProxyFactory_) public {
        voteProxyFactory = voteProxyFactory_;
    }

    function doInitiateLink(address hot) public {
        voteProxyFactory.initiateLink(hot);
    }

    function doApproveLink(address cold) public returns (VoteProxy) {
        return voteProxyFactory.approveLink(cold);
    }

    function doLinkSelf() public returns (VoteProxy) {
        return voteProxyFactory.linkSelf();
    }

    function doBreakLink() public {
        voteProxyFactory.breakLink();
    }

    function tryBreakLink() public returns (bool) {
        bytes memory sig = abi.encodeWithSignature("breakLink()");
        (bool ok, bytes memory ret) = address(voteProxyFactory).call(sig); ret;
        return ok;
    }

    function proxyApprove(address _proxy, DSToken _token) public {
        _token.approve(_proxy);
    }

    function proxyAddVotingWeight(VoteProxy _proxy, uint amount) public {
        _proxy.addVotingWeight(amount);
    }

    function proxyRemoveVotingWeight(VoteProxy _proxy, uint amount) public {
        _proxy.removeVotingWeight(amount);
    }
}


contract VoteProxyFactoryTest is DSTest {
    uint256 constant electionSize = 3;

    VoteProxyFactory voteProxyFactory;
    DSToken gov;
    DSToken iou;
    VoteQuorum voteQuorum;

    VoteUser cold;
    VoteUser hot;

    function setUp() public {
        gov = new DSToken("GOV");

        VoteQuorumFactory quorumFactory = new VoteQuorumFactory();
        voteQuorum = quorumFactory.newVoteQuorum(gov, electionSize);
        voteProxyFactory = new VoteProxyFactory(voteQuorum);
        cold = new VoteUser(voteProxyFactory);
        hot  = new VoteUser(voteProxyFactory);
    }

    function test_initiateLink() public {
        assertEq(voteProxyFactory.linkRequests(address(cold)), address(0));
        cold.doInitiateLink(address(hot));
        assertEq(voteProxyFactory.linkRequests(address(cold)), address(hot));
    }

    function test_approveLink() public {
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteProxyFactory.hotMap(address(hot))), address(0));
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(voteProxyFactory.hotMap(address(hot))));
        assertEq(address(voteProxyFactory.coldMap(address(cold)).cold()), address(cold));
        assertEq(address(voteProxyFactory.hotMap(address(hot)).hot()), address(hot));
    }

    function test_coldBreakLink() public {
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertTrue(address(voteProxyFactory.coldMap(address(cold))) != address(0));
        assertTrue(address(voteProxyFactory.hotMap(address(hot))) != address(0));
        cold.doBreakLink();
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteProxyFactory.hotMap(address(hot))), address(0));
    }

    function test_hotBreakLink() public {
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertTrue(address(voteProxyFactory.coldMap(address(cold))) != address(0));
        assertTrue(address(voteProxyFactory.hotMap(address(hot))) != address(0));
        hot.doBreakLink();
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteProxyFactory.hotMap(address(hot))), address(0));
    }

    function test_tryBreakLink() public {
        cold.doInitiateLink(address(hot));
        VoteProxy voteProxy = hot.doApproveLink(address(cold));
        voteQuorum.PROT().mint(address(cold), 1);
        cold.proxyApprove(address(voteProxy), voteQuorum.PROT());
        cold.proxyAddVotingWeight(voteProxy, 1);
        assertTrue(!cold.tryBreakLink());

        cold.proxyRemoveVotingWeight(voteProxy, 1);
        assertTrue(cold.tryBreakLink());
    }

    function test_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(0));
        VoteProxy voteProxy = cold.doLinkSelf();
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(voteProxy));
        assertEq(address(voteProxyFactory.coldMap(address(cold)).cold()), address(cold));
        assertEq(address(voteProxyFactory.hotMap(address(cold)).hot()), address(cold));
    }

    function testFail_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(0));
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertEq(address(voteProxyFactory.coldMap(address(cold))), address(hot));
        cold.doLinkSelf();
    }
}

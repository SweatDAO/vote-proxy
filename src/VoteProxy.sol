/// VoteProxy.sol

// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// vote w/ a hot or cold wallet using a proxy identity
pragma solidity >=0.4.24;

import "ds-token/token.sol";
import "ds-vote-quorum/VoteQuorum.sol";

contract VoteProxy {
    address public cold;
    address public hot;
    DSToken public gov;
    DSToken public iou;
    VoteQuorum public voteQuorum;

    // --- Events ---
    event AddVotingWeight(address sender, uint256 wad);
    event RemoveVotingWeight(address sender, uint256 wad);
    event RemoveAllVotingWeight(address sender, uint256 wad);
    event Vote(address sender, address[] candidates);
    event Vote(address sender, bytes32 ballot);

    constructor(VoteQuorum _voteQuorum, address _cold, address _hot) public {
        voteQuorum = _voteQuorum;
        cold = _cold;
        hot = _hot;

        gov = voteQuorum.PROT();
        iou = voteQuorum.IOU();
        gov.approve(address(voteQuorum), uint256(-1));
        iou.approve(address(voteQuorum), uint256(-1));
    }

    modifier isAuthorized() {
        require(msg.sender == hot || msg.sender == cold, "Sender must be a Cold or Hot Wallet");
        _;
    }

    function addVotingWeight(uint256 wad) public isAuthorized {
        gov.pull(cold, wad);              // protocol tokens from cold
        voteQuorum.addVotingWeight(wad);  // protocol tokens out, ious in
        emit AddVotingWeight(msg.sender, wad);
    }

    function removeVotingWeight(uint256 wad) public isAuthorized {
        voteQuorum.removeVotingWeight(wad);  // ious out, protocol tokens in
        gov.push(cold, wad);                 // protocol tokens to cold
        emit RemoveVotingWeight(msg.sender, wad);
    }

    function removeAllVotingWeight() public isAuthorized {
        voteQuorum.removeVotingWeight(voteQuorum.deposits(address(this)));
        emit RemoveAllVotingWeight(msg.sender, gov.balanceOf(address(this)));
        gov.push(cold, gov.balanceOf(address(this)));
    }

    function vote(address[] memory candidates) public isAuthorized returns (bytes32) {
        emit Vote(msg.sender, candidates);
        return voteQuorum.vote(candidates);
    }

    function vote(bytes32 ballot) public isAuthorized {
        emit Vote(msg.sender, ballot);
        voteQuorum.vote(ballot);
    }
}

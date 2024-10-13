

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EduBaseModule = buildModule("EduBaseModule", (m: any) => {
 
  // Deploy LanSeller with token address and price feed
  const eduBaseToken = m.contract("EduBaseToken");
  const eduBaseGovernance = m.contract("EduBaseGovernance",[eduBaseToken]);
  const eduBase = m.contract("EduBase", [eduBaseToken, eduBaseGovernance]);

  return {eduBaseToken, eduBaseGovernance, eduBase };
});

export default EduBaseModule;
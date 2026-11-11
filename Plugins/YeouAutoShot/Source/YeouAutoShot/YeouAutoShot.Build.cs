// =============================================================================
//  YeouAutoShot (YeouWatch 1.1.0)
//  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
//  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
// =============================================================================
using UnrealBuildTool;

public class YeouAutoShot : ModuleRules
{
	public YeouAutoShot(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine" });
		PrivateDependencyModuleNames.AddRange(new string[] { "RHI" });
	}
}

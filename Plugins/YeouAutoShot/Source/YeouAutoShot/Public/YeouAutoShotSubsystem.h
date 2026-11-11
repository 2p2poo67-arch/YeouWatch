// =============================================================================
//  YeouAutoShot (YeouWatch 1.1.0)
//  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
//  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
// =============================================================================
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "YeouAutoShotSubsystem.generated.h"

class ACameraActor;

/**
 * Takes a fixed list of screenshots and quits, so an AI assistant can look at the game without remote screen control.
 * Created only when the game is started with -YeouAutoShot (the watcher does this for Saved\shot_request.txt).
 *
 * Shot list, in this order:
 *   1. "00_game"  - the normal player view after the level settles
 *   2. every actor with the tag  YeouShot  (optional second tag  YeouName=corridor_02  names the file;
 *      a CameraActor also gives its field of view)
 *   3. every line of  Saved\yeou_shots.txt :  name  x y z  pitch yaw  [fov]   (the assistant can edit this file)
 *
 * Command line:
 *   -YeouShots=corridor        only shots whose name contains this text (one word, no commas)
 *   -YeouShotDir=<folder>      output folder (default Saved\AutoShots\<yyyyMMdd_HHmmss>)
 *   -YeouShotWait=6            seconds to wait before the first shot (loading, auto exposure)
 *   -YeouShotSettle=2.5        seconds after each camera move
 *   -YeouShotCVars=r.Foo=1;my.Bar=0.5   console values set before shooting (before/after comparisons)
 *   -YeouShotStay              keep the game open afterwards
 *
 * Output: <dir>\NN_name.png, <dir>\shots.json (frame ms, GPU ms, camera per shot), Saved\shot_status.txt
 * RUNNING / DONE / FAILED - the watcher then builds contact_sheet.jpg from the PNGs.
 */
UCLASS()
class YEOUAUTOSHOT_API UYeouAutoShotSubsystem : public UTickableWorldSubsystem
{
	GENERATED_BODY()

public:
	static bool Wanted();

	virtual bool ShouldCreateSubsystem(UObject* Outer) const override;
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Tick(float DeltaTime) override;
	virtual TStatId GetStatId() const override;
	virtual bool IsTickableWhenPaused() const override { return true; }

private:
	struct FShot
	{
		FString Name;
		bool bGameView = false;
		FVector Loc = FVector::ZeroVector;
		FRotator Rot = FRotator::ZeroRotator;
		float Fov = 0.f;
	};
	struct FPerf { int32 N = 0; double FrameMs = 0.0; double WorstMs = 0.0; double GpuMs = 0.0; };
	enum class EPhase : uint8 { Wait, Settle, AfterShot, Write, Quit, Done };

	void BuildShots();
	void ApplyShot(const FShot& S);
	void SetStatus(const FString& S) const;
	void Fail(const FString& Why);
	void WriteManifest() const;

	TArray<FShot> Shots;
	TArray<FString> Taken;
	TMap<FString, FPerf> Perf;
	TWeakObjectPtr<ACameraActor> CamActor;
	FString OutDir;
	FString Filter;
	double Started = 0.0;
	double PhaseT = 0.0;
	double WaitFirst = 6.0;
	double SettleEach = 2.5;
	int32 Index = 0;
	EPhase Phase = EPhase::Wait;
};

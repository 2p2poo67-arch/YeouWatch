// =============================================================================
//  YeouAutoShot (YeouWatch 1.1.0)
//  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
//  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
// =============================================================================
#include "YeouAutoShotSubsystem.h"

#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Camera/PlayerCameraManager.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerController.h"
#include "HAL/FileManager.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "HAL/PlatformTime.h"
#include "Misc/App.h"
#include "Misc/CommandLine.h"
#include "Misc/DateTime.h"
#include "Misc/FileHelper.h"
#include "Misc/Parse.h"
#include "Misc/Paths.h"
#include "RHI.h"
#include "UnrealClient.h"

DEFINE_LOG_CATEGORY_STATIC(LogYeouAutoShot, Log, All);

namespace
{
	constexpr double AfterShotWait = 0.9; // time for the PNG to be written
	constexpr double PerfWindow = 1.5;    // last seconds of each settle are measured for shots.json
	constexpr double GiveUpBase = 120.0;

	FString StatusPath() { return FPaths::ConvertRelativePathToFull(FPaths::ProjectSavedDir() / TEXT("shot_status.txt")); }
	FString Esc(const FString& S) { return S.ReplaceCharWithEscapedChar(); }
}

bool UYeouAutoShotSubsystem::Wanted() { return FParse::Param(FCommandLine::Get(), TEXT("YeouAutoShot")); }

bool UYeouAutoShotSubsystem::ShouldCreateSubsystem(UObject* Outer) const
{
	if (!Wanted()) return false;
	const UWorld* W = Cast<UWorld>(Outer);
	return W && (W->WorldType == EWorldType::Game || W->WorldType == EWorldType::PIE);
}

void UYeouAutoShotSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	FParse::Value(FCommandLine::Get(), TEXT("YeouShotWait="), WaitFirst);
	FParse::Value(FCommandLine::Get(), TEXT("YeouShotSettle="), SettleEach);
	FParse::Value(FCommandLine::Get(), TEXT("YeouShots="), Filter);

	// -YeouShotCVars=r.Foo=1;my.Bar=0.5 : same run, different values -> before/after comparisons
	FString CV;
	if (FParse::Value(FCommandLine::Get(), TEXT("YeouShotCVars="), CV, false))
	{
		TArray<FString> Parts;
		CV.ParseIntoArray(Parts, TEXT(";"), true);
		for (const FString& P : Parts)
		{
			FString Name, Val;
			if (!P.Split(TEXT("="), &Name, &Val)) continue;
			if (IConsoleVariable* V = IConsoleManager::Get().FindConsoleVariable(*Name.TrimStartAndEnd()))
			{
				V->Set(*Val.TrimStartAndEnd(), ECVF_SetByCode);
				UE_LOG(LogYeouAutoShot, Log, TEXT("cvar %s = %s"), *Name, *Val);
			}
			else UE_LOG(LogYeouAutoShot, Warning, TEXT("cvar not found: %s"), *Name);
		}
	}
}

TStatId UYeouAutoShotSubsystem::GetStatId() const { RETURN_QUICK_DECLARE_CYCLE_STAT(UYeouAutoShotSubsystem, STATGROUP_Tickables); }

void UYeouAutoShotSubsystem::SetStatus(const FString& S) const
{
	FFileHelper::SaveStringToFile(S + LINE_TERMINATOR, *StatusPath(), FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
	UE_LOG(LogYeouAutoShot, Log, TEXT("%s"), *S);
}

void UYeouAutoShotSubsystem::Fail(const FString& Why)
{
	SetStatus(FString::Printf(TEXT("FAILED %s | %s | shots %d"), *Why, *OutDir, Taken.Num()));
	if (!OutDir.IsEmpty()) WriteManifest();
	Phase = EPhase::Quit; PhaseT = FPlatformTime::Seconds();
}

void UYeouAutoShotSubsystem::BuildShots()
{
	Shots.Reset();
	{
		FShot S; S.Name = TEXT("game"); S.bGameView = true;
		Shots.Add(S);
	}
	// actors tagged YeouShot (+ optional YeouName=...)
	for (TActorIterator<AActor> It(GetWorld()); It; ++It)
	{
		AActor* A = *It;
		if (!A || !A->ActorHasTag(TEXT("YeouShot"))) continue;
		FShot S;
		S.Name = A->GetName();
		for (const FName& T : A->Tags)
		{
			const FString TS = T.ToString();
			if (TS.StartsWith(TEXT("YeouName="))) S.Name = TS.Mid(9);
		}
		S.Loc = A->GetActorLocation();
		S.Rot = A->GetActorRotation();
		if (const ACameraActor* C = Cast<ACameraActor>(A)) S.Fov = C->GetCameraComponent()->FieldOfView;
		Shots.Add(S);
	}
	// Saved\yeou_shots.txt : name x y z pitch yaw [fov]   ('#' starts a comment)
	TArray<FString> Lines;
	if (FFileHelper::LoadFileToStringArray(Lines, *(FPaths::ProjectSavedDir() / TEXT("yeou_shots.txt"))))
	{
		for (const FString& L : Lines)
		{
			FString Line = L.TrimStartAndEnd();
			if (Line.IsEmpty() || Line.StartsWith(TEXT("#"))) continue;
			TArray<FString> T;
			Line.ParseIntoArrayWS(T);
			if (T.Num() < 6) { UE_LOG(LogYeouAutoShot, Warning, TEXT("bad line in yeou_shots.txt: %s"), *Line); continue; }
			FShot S;
			S.Name = T[0];
			S.Loc = FVector(FCString::Atod(*T[1]), FCString::Atod(*T[2]), FCString::Atod(*T[3]));
			S.Rot = FRotator(FCString::Atof(*T[4]), FCString::Atof(*T[5]), 0.f);
			if (T.Num() > 6) S.Fov = FCString::Atof(*T[6]);
			Shots.Add(S);
		}
	}
	if (!Filter.IsEmpty()) Shots.RemoveAll([this](const FShot& S) { return !S.Name.Contains(Filter); });
	for (int32 I = 0; I < Shots.Num(); ++I) Shots[I].Name = FString::Printf(TEXT("%02d_%s"), I, *Shots[I].Name);
}

void UYeouAutoShotSubsystem::ApplyShot(const FShot& S)
{
	APlayerController* PC = GetWorld() ? GetWorld()->GetFirstPlayerController() : nullptr;
	if (!PC) return;
	if (APlayerCameraManager* PCM = PC->PlayerCameraManager) { PCM->StopAllCameraShakes(true); PCM->StopCameraFade(); }
	if (S.bGameView)
	{
		if (APawn* P = PC->GetPawn()) PC->SetViewTarget(P);
		return;
	}
	if (!CamActor.IsValid())
	{
		FActorSpawnParameters SP;
		SP.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
		CamActor = GetWorld()->SpawnActor<ACameraActor>(ACameraActor::StaticClass(), FTransform::Identity, SP);
		if (CamActor.IsValid()) CamActor->GetCameraComponent()->bConstrainAspectRatio = false;
	}
	if (!CamActor.IsValid()) return;
	CamActor->SetActorLocationAndRotation(S.Loc, S.Rot);
	if (S.Fov > 0.f) CamActor->GetCameraComponent()->SetFieldOfView(S.Fov);
	PC->SetViewTarget(CamActor.Get());
}

void UYeouAutoShotSubsystem::Tick(float DeltaTime)
{
	const double Now = FPlatformTime::Seconds();
	if (Started == 0.0)
	{
		Started = PhaseT = Now;
		FString Dir;
		if (!FParse::Value(FCommandLine::Get(), TEXT("YeouShotDir="), Dir) || Dir.IsEmpty())
			Dir = FPaths::ProjectSavedDir() / TEXT("AutoShots") / FDateTime::Now().ToString(TEXT("%Y%m%d_%H%M%S"));
		OutDir = FPaths::ConvertRelativePathToFull(Dir);
		IFileManager::Get().MakeDirectory(*OutDir, true);
		SetStatus(FString::Printf(TEXT("RUNNING %s"), *OutDir));
	}
	if (Phase == EPhase::Done) return;
	if (Phase != EPhase::Quit && Now - Started > GiveUpBase + WaitFirst + Shots.Num() * (SettleEach + 3.0)) { Fail(TEXT("timeout")); return; }

	switch (Phase)
	{
	case EPhase::Wait:
		if (Now - PhaseT < WaitFirst) break;
		BuildShots();
		if (Shots.Num() == 0) { Fail(TEXT("no shots match the filter")); break; }
		Index = 0;
		ApplyShot(Shots[0]);
		Phase = EPhase::Settle; PhaseT = Now;
		break;
	case EPhase::Settle:
	{
		if (Now - PhaseT > SettleEach - PerfWindow)
		{
			FPerf& Pf = Perf.FindOrAdd(Shots[Index].Name);
			const double Ms = FApp::GetDeltaTime() * 1000.0;
			Pf.N++; Pf.FrameMs += Ms; Pf.WorstMs = FMath::Max(Pf.WorstMs, Ms);
			Pf.GpuMs += FPlatformTime::ToMilliseconds64(RHIGetGPUFrameCycles(0));
		}
		if (Now - PhaseT < SettleEach) break;
		const FShot& S = Shots[Index];
		FScreenshotRequest::RequestScreenshot(OutDir / (S.Name + TEXT(".png")), false, false);
		Taken.Add(S.Name);
		SetStatus(FString::Printf(TEXT("RUNNING %s | %d/%d %s"), *OutDir, Index + 1, Shots.Num(), *S.Name));
		Phase = EPhase::AfterShot; PhaseT = Now;
		break;
	}
	case EPhase::AfterShot:
		if (Now - PhaseT < AfterShotWait) break;
		if (++Index < Shots.Num()) { ApplyShot(Shots[Index]); Phase = EPhase::Settle; PhaseT = Now; break; }
		Phase = EPhase::Write;
		break;
	case EPhase::Write:
		WriteManifest();
		SetStatus(FString::Printf(TEXT("DONE %s | shots %d"), *OutDir, Taken.Num()));
		Phase = EPhase::Quit; PhaseT = Now;
		break;
	case EPhase::Quit:
		if (Now - PhaseT < 1.5) break;
		Phase = EPhase::Done;
		if (!FParse::Param(FCommandLine::Get(), TEXT("YeouShotStay"))) FPlatformMisc::RequestExit(false);
		break;
	default: break;
	}
}

void UYeouAutoShotSubsystem::WriteManifest() const
{
	FString Res;
	if (GEngine && GEngine->GameViewport && GEngine->GameViewport->Viewport)
	{
		const FIntPoint Sz = GEngine->GameViewport->Viewport->GetSizeXY();
		Res = FString::Printf(TEXT("%dx%d"), Sz.X, Sz.Y);
	}
	FString J = TEXT("{\n  \"tool\": \"YeouAutoShot 1.1.0\",\n  \"dir\": \"") + Esc(OutDir.Replace(TEXT("\\"), TEXT("/"))) + TEXT("\",\n  \"res\": \"") + Res + TEXT("\",\n  \"shots\": [\n");
	for (int32 I = 0; I < Shots.Num(); ++I)
	{
		const FShot& S = Shots[I];
		const FPerf* Pf = Perf.Find(S.Name);
		const double K = Pf && Pf->N > 0 ? 1.0 / Pf->N : 0.0;
		J += FString::Printf(TEXT("    {\"name\": \"%s\", \"taken\": %s, \"frame_ms\": %.2f, \"worst_ms\": %.2f, \"gpu_ms\": %.2f, \"game_view\": %s, \"cam\": [%.0f, %.0f, %.0f], \"rot\": [%.1f, %.1f], \"fov\": %.0f}%s\n"),
			*Esc(S.Name), Taken.Contains(S.Name) ? TEXT("true") : TEXT("false"),
			Pf ? Pf->FrameMs * K : 0.0, Pf ? Pf->WorstMs : 0.0, Pf ? Pf->GpuMs * K : 0.0,
			S.bGameView ? TEXT("true") : TEXT("false"), S.Loc.X, S.Loc.Y, S.Loc.Z, S.Rot.Pitch, S.Rot.Yaw, S.Fov,
			I + 1 < Shots.Num() ? TEXT(",") : TEXT(""));
	}
	J += TEXT("  ]\n}\n");
	FFileHelper::SaveStringToFile(J, *(OutDir / TEXT("shots.json")), FFileHelper::EEncodingOptions::ForceUTF8WithoutBOM);
}

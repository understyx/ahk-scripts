#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")

CheckingActive := false
TrackerActive := false
CheckInterval := 30 ; 30ms stable execution window
MovementState := "none" ; Global string tracking movement state

; --- CONFIGURATION DATA ---
Melee_X := 1666,      Melee_Y := 1220,      Melee_Color := 0x1ACF19
Shooting_X := 1666,   Shooting_Y := 1260,   Shooting_Color := 0x308BE7

MainHand_Start_X := 1735,  MainHand_Start_Y := 1250
Ranged_Start_X := 1735,    Ranged_Start_Y := 1283 

MainHand_X := 2100,   MainHand_Y := 1250,   MainHand_Color := 0x6699FF
Ranged_X := 2100,     Ranged_Y := 1283,     Ranged_Color := 0x4DFF80

Sq1_X := 1390, Sq1_Y := 1080, Sq_Color := 0x00FF00
Sq2_X := 1450, Sq2_Y := 1080
Sq3_X := 1510, Sq3_Y := 1080
Sq4_X := 1570, Sq4_Y := 1080
Sq5_X := 1630, Sq5_Y := 1080

Sq6_X := 1690, Sq6_Y := 1080, Cast_Color := 0xFF0000 
Sq7_X := 1745, Sq7_Y := 1080, GCD_Color := 0xFF0000  

; --- HOTKEYS ---

F1:: {
    global CheckingActive
    if (!CheckingActive) {
        CheckingActive := true
        SetTimer(WeavingEngine, CheckInterval)
        ToolTip("Engine: RUNNING")
        SetTimer(() => ToolTip(), -1000)
    }
}

F2:: {
    global CheckingActive
    if (CheckingActive) {
        CheckingActive := false
        SetTimer(WeavingEngine, 0)
        StopMovement()
        ToolTip("Engine: STOPPED")
        SetTimer(() => ToolTip(), -1000)
    }
}

F3::
{
    global TrackerActive
    TrackerActive := !TrackerActive
    SetTimer(WatchMouse, TrackerActive ? 50 : 0)
    if (!TrackerActive) {
        ToolTip()
    }
}

; --- CORE ENGINES ---

WatchMouse() {
    try {
        MouseGetPos(&mX, &mY)
        ToolTip("X: " mX "`nY: " mY "`nColor (RGB): " Format("0x{:06X}", PixelGetColor(mX, mY)))
    } catch {
        ToolTip("Error reading screen data.")
    }
}

WeavingEngine() {
    global MovementState
    try {
        ; 1. ABSOLUTE CAST PROTECTION (Must be first)
        IsCasting := (PixelGetColor(Sq6_X, Sq6_Y) == Cast_Color)
        if (IsCasting) {
            if (MovementState != "none") {
                SetMovement("none") 
            }
            return
        }

        ; 2. RANGE DETECTION
        InMelee    := (PixelGetColor(Melee_X, Melee_Y) == Melee_Color)
        InShooting := (PixelGetColor(Shooting_X, Shooting_Y) == Shooting_Color)

        ; 3. PHYSICAL BOUNDARY BRAKES 
        if (InMelee && MovementState == "forward") {
            SetMovement("none")
            return
        }
        if (InShooting && MovementState == "backward") {
            SetMovement("none")
            return
        }

        ; 4. SWING & COOLDOWN SCAN
        IsGCD           := (PixelGetColor(Sq7_X, Sq7_Y) == GCD_Color)
        MainHandReady   := (PixelGetColor(MainHand_X, MainHand_Y) == MainHand_Color)
        RangedReady     := (PixelGetColor(Ranged_X, Ranged_Y) == Ranged_Color)
        MainHandAtStart := (PixelGetColor(MainHand_Start_X, MainHand_Start_Y) == MainHand_Color)
        RangedAtStart   := (PixelGetColor(Ranged_Start_X, Ranged_Start_Y) == Ranged_Color) 

        ExplosiveReady := (PixelGetColor(Sq1_X, Sq1_Y) == Sq_Color)
        AimedReady     := (PixelGetColor(Sq2_X, Sq2_Y) == Sq_Color)
        SerpentReady   := (PixelGetColor(Sq3_X, Sq3_Y) == Sq_Color)
        RaptorReady    := (PixelGetColor(Sq4_X, Sq4_Y) == Sq_Color)
        TrapReady      := (PixelGetColor(Sq5_X, Sq5_Y) == Sq_Color)

        ; 5. ESCAPE MELEE AFTER SWING COMPLETED
        if (InMelee && !MainHandReady && !MainHandAtStart && !TrapReady && !RaptorReady) {
            SetMovement("backward")
            return
        }

        ; 6. PRIORITY EXECUTION TREE
        if (InShooting && !IsGCD) {
            if (ExplosiveReady) { 
                SendEvent("4")
                return 
            }
            if (AimedReady) { 
                SendEvent("3")
                return 
            }
        }

        if (TrapReady) {
            if (!InMelee) { 
                SetMovement("forward")
                return 
            } else { 
                SendEvent("^3")
                return 
            }
        }

        if (InShooting && SerpentReady && !IsGCD) { 
            SendEvent("1")
            return 
        }

        if (InShooting && RangedReady) { 
            if (MovementState != "none") { 
                SetMovement("none") 
            }
            return 
        } 

        GcdWeaveReady := (IsGCD && (ExplosiveReady || AimedReady))
        if (RaptorReady || MainHandReady || GcdWeaveReady) {
            if (!InMelee) { 
                SetMovement("forward")
                return 
            } else if (RaptorReady) { 
                SendEvent("+e")
                return 
            }
        }

        ; Safe fallback disengage condition
        if (InMelee && !TrapReady && !RaptorReady && !IsGCD) { 
            SetMovement("backward") 
            return 
        }

        if (InShooting && !ExplosiveReady && !AimedReady && !SerpentReady && !IsGCD) { 
            SendEvent("2")
            return 
        }

        if (RangedReady && !InShooting && !InMelee) { 
            SetMovement("backward")
            return 
        }

    } catch {
        ; Graceful skip on pixel read lag
    }
}

; --- STATE-SAFE MOVEMENT EXECUTOR ---
SetMovement(target) {
    global MovementState 
    if (target == MovementState) {
        return 
    }
    
    currentKey := (MovementState == "forward") ? "w" : (MovementState == "backward") ? "s" : ""
    targetKey  := (target == "forward") ? "w" : (target == "backward") ? "s" : ""

    if (currentKey != "") {
        SendEvent("{" currentKey " up}")
    }
    if (targetKey != "") {
        SendEvent("{" targetKey " down}")
    }
    MovementState := target
}

StopMovement() {
    SetMovement("none")
}

Esc:: {
    StopMovement()
    ExitApp()
}

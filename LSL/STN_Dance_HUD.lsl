// STN Dance HUD v1.7.9 - controller
// Install BOTH this script and STN_Dance_Partner.lsl in the SAME HUD prim.
// Owner animation permissions stay in this script; partner permissions stay in worker.
// One invited partner is supported by this revision.
integer MENU_CHANNEL;
key OWNER;
list anim_real = [];
list anim_display = [];
list nearby_names = [];
list nearby_keys = [];
integer PAGE = 0;
integer INVITE_PAGE = 0;
integer PER_PAGE = 9;
integer HAS_OWNER_PERMS = FALSE;
string CURRENT_ANIM = "";
float CURRENT_DURATION = 0.0;
integer LOOPING = FALSE;
integer PARTNER_READY = FALSE;
key PARTNER = NULL_KEY;
string version = "1.7.9";

privateSay(string s) { llOwnerSay(s); }
string safeButton(string s) {
    if (llStringLength(s) > 24) return llGetSubString(s, 0, 23);
    return s;
}
string cleanName(string s) {
    integer p = llSubStringIndex(s, "/");
    if (p != -1) s = llStringTrim(llGetSubString(s, p + 1, -1), STRING_TRIM);
    list a = llParseString2List(s, ["_"], []);
    if (llGetListLength(a) >= 2)
        return llList2String(a, 0) + " " + llList2String(a, 1);
    return s;
}
float parseDuration(string s) {
    integer p = llSubStringIndex(s, "sec");
    if (p != -1) {
        float v = (float)llGetSubString(s, 0, p - 1);
        if (v >= 2.0) return v;
    }
    return 30.0;
}
scanAnimations() {
    anim_real = [];
    anim_display = [];
    integer i;
    integer n = llGetInventoryNumber(INVENTORY_ANIMATION);
    for (i = 0; i < n; ++i) {
        string a = llGetInventoryName(INVENTORY_ANIMATION, i);
        anim_real += [a];
        anim_display += [cleanName(a)];
    }
    privateSay("Loaded " + (string)n + " dances.");
}
integer ownerPerms() {
    return ((llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) != 0
        && llGetPermissionsKey() == OWNER);
}
requestOwnerPerms() {
    HAS_OWNER_PERMS = FALSE;
    llRequestPermissions(OWNER, PERMISSION_TRIGGER_ANIMATION);
}
stopDance() {
    LOOPING = FALSE;
    llSetTimerEvent(0.0);
    if (ownerPerms() && CURRENT_ANIM != "") llStopAnimation(CURRENT_ANIM);
    llMessageLinked(LINK_SET, 7002, "STOP", NULL_KEY);
    CURRENT_ANIM = "";
    CURRENT_DURATION = 0.0;
    privateSay("All dances stopped.");
}
playDance(string a) {
    if (!ownerPerms()) {
        HAS_OWNER_PERMS = FALSE;
        privateSay("Owner permissions unavailable; requesting again.");
        requestOwnerPerms();
        return;
    }
    stopDance();
    CURRENT_ANIM = a;
    CURRENT_DURATION = parseDuration(a);
    LOOPING = TRUE;
    llStartAnimation(a);
    if (PARTNER_READY) llMessageLinked(LINK_SET, 7002, "PLAY|" + a, NULL_KEY);
    llSetTimerEvent(CURRENT_DURATION - 0.5);
    privateSay("Playing: " + a);
}
showMain() {
    llDialog(OWNER, "STN Dance HUD v" + version,
        ["Dances", "Invite", "Stop"], MENU_CHANNEL);
}
showDanceMenu() {
    list buttons = [];
    integer start = PAGE * PER_PAGE;
    integer end = start + PER_PAGE - 1;
    integer i;
    for (i = start; i <= end && i < llGetListLength(anim_display); ++i)
        buttons += [safeButton(llList2String(anim_display, i))];
    if (PAGE > 0) buttons += ["<< Prev"];
    if (end < llGetListLength(anim_display) - 1) buttons += ["Next >>"];
    buttons += ["Back"];
    llDialog(OWNER, "Dances Page " + (string)(PAGE + 1), buttons, MENU_CHANNEL);
}
showInviteMenu() {
    integer n = llGetListLength(nearby_names);
    if (!n) { privateSay("Nobody nearby."); return; }
    list buttons = [];
    integer start = INVITE_PAGE * PER_PAGE;
    integer end = start + PER_PAGE - 1;
    integer i;
    for (i = start; i <= end && i < n; ++i)
        buttons += [safeButton(llList2String(nearby_names, i))];
    if (INVITE_PAGE > 0) buttons += ["Invite Prev"];
    if (end < n - 1) buttons += ["Invite Next"];
    buttons += ["Back"];
    llDialog(OWNER, "Select Dance Partner", buttons, MENU_CHANNEL);
}
scanNearby() {
    nearby_names = [];
    nearby_keys = [];
    INVITE_PAGE = 0;
    llSensor("", NULL_KEY, AGENT, 20.0, PI);
}
default {
    state_entry() {
        OWNER = llGetOwner();
        MENU_CHANNEL = -1000000 - (integer)llFrand(1000000.0);
        llListen(MENU_CHANNEL, "", OWNER, "");
        scanAnimations();
        requestOwnerPerms();
        privateSay("STN Dance HUD v" + version + " Ready");
    }
    attach(key id) {
        if (id != NULL_KEY) {
            OWNER = llGetOwner();
            PARTNER = NULL_KEY;
            PARTNER_READY = FALSE;
            LOOPING = FALSE;
            CURRENT_ANIM = "";
            llSetTimerEvent(0.0);
            llMessageLinked(LINK_SET, 7002, "CLEAR", NULL_KEY);
            requestOwnerPerms();
        } else {
            llMessageLinked(LINK_SET, 7002, "CLEAR", NULL_KEY);
        }
    }
    run_time_permissions(integer perm) {
        HAS_OWNER_PERMS = ownerPerms();
        if (HAS_OWNER_PERMS) privateSay("Owner animation permissions granted.");
    }
    touch_start(integer total) {
        if (llDetectedKey(0) == OWNER) showMain();
    }
    sensor(integer total) {
        nearby_names = [];
        nearby_keys = [];
        integer i;
        for (i = 0; i < total; ++i) {
            key k = llDetectedKey(i);
            if (k != OWNER) {
                nearby_names += [safeButton(llDetectedName(i))];
                nearby_keys += [k];
            }
        }
        showInviteMenu();
    }
    no_sensor() { privateSay("Nobody nearby to invite."); }
    link_message(integer sender, integer num, string msg, key id) {
        if (num != 7003) return;
        if (msg == "READY" && id == PARTNER) {
            PARTNER_READY = TRUE;
            privateSay("Partner connected.");
            if (LOOPING && CURRENT_ANIM != "")
                llMessageLinked(LINK_SET, 7002, "PLAY|" + CURRENT_ANIM, NULL_KEY);
        } else if (msg == "OFFLINE" && id == PARTNER) {
            PARTNER_READY = FALSE;
            PARTNER = NULL_KEY;
            privateSay("Partner disconnected. Reinvite after relog.");
        } else if (msg == "DENIED" && id == PARTNER) {
            PARTNER_READY = FALSE;
            PARTNER = NULL_KEY;
            privateSay("Partner permissions not granted.");
        }
    }
    listen(integer ch, string name, key id, string msg) {
        if (id != OWNER) return;
        if (msg == "Dances") showDanceMenu();
        else if (msg == "Invite") scanNearby();
        else if (msg == "Stop") stopDance();
        else if (msg == "Next >>") { ++PAGE; showDanceMenu(); }
        else if (msg == "<< Prev") {
            if (PAGE > 0) --PAGE;
            showDanceMenu();
        }
        else if (msg == "Invite Next") { ++INVITE_PAGE; showInviteMenu(); }
        else if (msg == "Invite Prev") {
            if (INVITE_PAGE > 0) --INVITE_PAGE;
            showInviteMenu();
        }
        else if (msg == "Back") showMain();
        else {
            integer i = llListFindList(nearby_names, [msg]);
            if (i != -1) {
                PARTNER = llList2Key(nearby_keys, i);
                PARTNER_READY = FALSE;
                llMessageLinked(LINK_SET, 7002, "INVITE|" + (string)PARTNER, NULL_KEY);
                privateSay("Permission request sent.");
                return;
            }
            i = llListFindList(anim_display, [msg]);
            if (i != -1) playDance(llList2String(anim_real, i));
        }
    }
    timer() {
        if (!LOOPING || CURRENT_ANIM == "") { llSetTimerEvent(0.0); return; }
        if (!ownerPerms()) {
            HAS_OWNER_PERMS = FALSE;
            LOOPING = FALSE;
            llSetTimerEvent(0.0);
            llMessageLinked(LINK_SET, 7002, "STOP", NULL_KEY);
            CURRENT_ANIM = "";
            privateSay("Owner animation permissions lost; playback stopped.");
            return;
        }
        llStopAnimation(CURRENT_ANIM);
        llStartAnimation(CURRENT_ANIM);
        if (PARTNER_READY) llMessageLinked(LINK_SET, 7002, "PLAY|" + CURRENT_ANIM, NULL_KEY);
    }
    changed(integer change) {
        if (change & CHANGED_INVENTORY) scanAnimations();
        if (change & CHANGED_OWNER) llResetScript();
    }
    on_rez(integer p) { llResetScript(); }
}

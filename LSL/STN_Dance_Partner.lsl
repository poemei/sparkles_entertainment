// STN Dance Partner v1.7.9
// Separate script required: one animation permission holder per LSL script.
// Put this script in the same HUD prim as STN_Dance_HUD.lsl.
// On logout/permission loss, stop retries; partner must be reinvited.
key partner = NULL_KEY;
string active = "";
integer ready = FALSE;
integer pending = FALSE;
integer online() {
    return (partner != NULL_KEY && llGetAgentSize(partner) != ZERO_VECTOR);
}
integer permitted() {
    return (ready && online() &&
        (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) != 0 &&
        llGetPermissionsKey() == partner);
}
clearPartner() {
    // Never call animation functions unless the correct permission is active.
    if (permitted() && active != "") llStopAnimation(active);
    active = "";
    ready = FALSE;
    pending = FALSE;
    partner = NULL_KEY;
    llSetTimerEvent(0.0);
}
default {
    state_entry() { clearPartner(); }
    link_message(integer sender, integer num, string msg, key id) {
        if (num != 7002) return;
        if (msg == "CLEAR") { clearPartner(); return; }
        if (msg == "STOP") {
            if (permitted() && active != "") llStopAnimation(active);
            active = "";
            return;
        }
        if (llSubStringIndex(msg, "INVITE|") == 0) {
            key target = (key)llGetSubString(msg, 7, -1);
            clearPartner();
            if (target == NULL_KEY) return;
            partner = target;
            pending = TRUE;
            llSetTimerEvent(2.0);
            llRequestPermissions(partner, PERMISSION_TRIGGER_ANIMATION);
            return;
        }
        if (llSubStringIndex(msg, "PLAY|") == 0) {
            if (!permitted()) return;
            string next = llGetSubString(msg, 5, -1);
            if (next == "") return;
            if (active != "") llStopAnimation(active);
            active = next;
            llStartAnimation(active);
        }
    }
    run_time_permissions(integer perm) {
        pending = FALSE;
        if (partner == NULL_KEY) return;
        if ((perm & PERMISSION_TRIGGER_ANIMATION) &&
            llGetPermissionsKey() == partner && online()) {
            ready = TRUE;
            llMessageLinked(LINK_SET, 7003, "READY", partner);
        } else {
            key old = partner;
            clearPartner();
            llMessageLinked(LINK_SET, 7003, "DENIED", old);
        }
    }
    timer() {
        if (partner == NULL_KEY) { llSetTimerEvent(0.0); return; }
        if (!online() || (ready && !permitted())) {
            key old = partner;
            clearPartner();
            llMessageLinked(LINK_SET, 7003, "OFFLINE", old);
        }
        // Pending permissions are not retried: only a new invitation may request.
    }
    attach(key id) { clearPartner(); }
    changed(integer c) {
        if (c & CHANGED_OWNER) llResetScript();
    }
    on_rez(integer p) { llResetScript(); }
}

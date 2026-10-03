from pathlib import Path
import os
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class FinalUxContractTests(unittest.TestCase):
    def test_chat_selection_waits_for_saved_status_without_marking_read(self):
        friends = read("FriendsPanelV3.qml")
        service = read("Service.qml")
        self.assertIn("property int statusRevision: 0", service)
        self.assertIn("root.statusRevision += 1", service)
        self.assertIn("readonly property int serviceStatusRevision: root.service ? root.service.statusRevision : 0", friends)
        completed = service[service.index("Component.onCompleted:"):]
        self.assertIn("root.refresh()", completed)
        self.assertNotIn("if (root.uiOpen) root.refresh()", completed)
        self.assertIn("onServiceChanged: {", friends)
        status_revision = friends[friends.index("onServiceStatusRevisionChanged:"):friends.index("onChatQueryChanged:")]
        self.assertIn("Qt.callLater(root.rebuildConversationRows)", status_revision)
        self.assertIn("Qt.callLater(root.restoreConversationAfterStatusRefresh)", status_revision)
        restore = friends[friends.index("function restoreConversationAfterStatusRefresh()"):friends.index("function sendMessage()")]
        self.assertIn('if (!root.open || root.page !== "chats"', restore)
        self.assertIn("root.selectedFriendKey = fs[0].public_key", restore)
        self.assertIn("root.selectedGroupId = gs[0].id", restore)
        self.assertNotIn("markConversationRead", restore)

    def test_omarchy_popup_exposes_a_configurable_layer_namespace(self):
        omarchy_path = os.environ.get("OMARCHY_PATH", "")
        base_popup = Path(omarchy_path) / "shell" / "Ui" / "KeyboardPanel.qml"
        if not base_popup.is_file():
            self.skipTest("OMARCHY_PATH must point at an Omarchy checkout for this integration contract")

        popup = base_popup.read_text(encoding="utf-8")
        friends = read("FriendsPanelV3.qml")
        self.assertIn('property string layerNamespace: "omarchy-keyboard-panel"', popup)
        self.assertIn("WlrLayershell.namespace: root.layerNamespace", popup)
        self.assertIn('layerNamespace: "omarchy-friends"', friends)

    def test_build_network_chat_opens_existing_friend_conversation(self):
        bar = read("BarWidget.qml")
        friends = read("FriendsPanelV3.qml")
        build = read("BuildNetworkPanelV3.qml")

        self.assertIn("function openFriendChat(publicKey)", bar)
        self.assertIn("function deliverPendingFriendChat()", bar)
        self.assertIn("openChatForPublicKey", bar)
        self.assertIn("function openChatForPublicKey(publicKey)", friends)
        self.assertIn("function builderActionLabel(publicKey)", build)
        self.assertIn('relation.status === "friends"', build)
        self.assertIn('return "Chat"', build)
        self.assertIn('return "Accept"', build)
        self.assertIn('return "Requested"', build)
        self.assertIn('return "Connect"', build)
        self.assertIn("root.hostWidget.openFriendChat(publicKey)", build)

    def test_build_network_does_not_resend_request_to_existing_friend(self):
        build = read("BuildNetworkPanelV3.qml")
        start = build.index("function connectBuilder(publicKey)")
        end = build.index("function repoIssues", start)
        body = build[start:end]
        friend_branch = body.split('relation.status === "friends"', 1)[1].split("var incoming", 1)[0]
        self.assertIn("openFriendChat(publicKey)", friend_branch)
        self.assertNotIn("requestFriend(publicKey)", friend_branch)
        self.assertIn("requestFriend(publicKey)", body)

    def test_chat_handoff_routes_nonfriends_to_truthful_state(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn('root.requestTab = "received"', friends)
        self.assertIn('root.requestTab = "sent"', friends)
        self.assertIn('root.page = "world"', friends)
        self.assertIn("Accept the request to start chatting", friends)
        self.assertIn("Friend request is still pending", friends)
        self.assertIn("Connect with this builder before starting a private chat", friends)

    def test_chat_close_and_blocked_people_recovery_contract(self):
        friends = read("FriendsPanelV3.qml")
        service = read("Service.qml")
        engine = read("bin/omarchy-friends")
        header = friends[friends.index("id: chatMoreButton"):friends.index("id: conversationDivider")]
        actions = friends[friends.index("id: chatActionsMenu"):friends.index("Dialog {\n            id: forwardDialog")]
        self.assertIn('text: "Close chat"', actions)
        self.assertIn("root.closeConversation()", actions)
        self.assertNotIn("blockGlobal", header + actions)
        self.assertIn('text: "Block"', friends)
        self.assertIn('text: "Blocked people"', friends)
        self.assertIn('text: "Unblock"', friends)
        self.assertIn("function unblockGlobal(publicKey)", service)
        self.assertIn('"unblock-global"', service)
        self.assertIn("def unblock_global(self, public_key)", engine)
        self.assertIn('command == "unblock-global"', engine)

    def test_private_shared_links_are_clickable_but_http_only(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn("function openSafeUrl(url)", friends)
        self.assertIn('url.indexOf("https://") !== 0', friends)
        self.assertIn('url.indexOf("http://") !== 0', friends)
        self.assertIn('["xdg-open", url]', friends)
        self.assertIn("onClicked: root.openSafeUrl", friends)

    def test_sent_request_actions_reserve_their_own_width(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn("id: sentRequestActions", friends)
        self.assertIn("parent.width - sentRequestActions.width - Style.space(60)", friends)
        self.assertIn('text: "Pending"', friends)
        self.assertIn('text: "Cancel"', friends)

    def test_chat_composer_and_attachment_picker_stay_inside_panel(self):
        friends = read("FriendsPanelV3.qml")
        bar = read("BarWidget.qml")
        chat_pane = friends[friends.index("GlassSurface {\n                            // Never force"):friends.index("// REQUESTS")]
        self.assertIn("width: Math.max(0, parent.width - conversationListSurface.width - parent.spacing)", chat_pane)
        self.assertIn("width: Math.max(0, parent.width - sendButton.width - attachmentButton.width - parent.spacing * 2)", chat_pane)
        self.assertIn("parent: contentArea\n            x: Math.max(Style.space(8), Math.min(contentArea.width - width - Style.space(8)", friends)
        self.assertNotIn("FileDialog {", friends)
        self.assertNotIn("FolderDialog {", friends)
        self.assertIn("function pickAttachment(folderMode, callback)", read("Service.qml"))
        self.assertIn('"pick-attachment"', read("Service.qml"))
        picker_command = read("bin/omarchy-friends")
        self.assertIn("def pick_attachment_from_portal(folder_mode=False):", picker_command)
        self.assertIn('"directory": dbus.Boolean(folder_mode)', picker_command)
        self.assertIn('"org.freedesktop.portal.FileChooser"', picker_command)
        self.assertIn('selected.startswith("file://")', picker_command)
        picker_flow = friends[friends.index("function openAttachmentBrowser("):friends.index("function syncEarlierMessages(")]
        self.assertIn("root.hostWidget.close()", picker_flow)
        self.assertLess(picker_flow.index("root.hostWidget.close()"), picker_flow.index("Qt.callLater(function()"))
        self.assertIn("root.service.pickAttachment(folderMode === true", picker_flow)
        self.assertIn("root.hostWidget.open()", picker_flow)
        self.assertNotIn("suspendedForSystemDialog", picker_flow)
        self.assertIn('layerNamespace: "omarchy-friends"', friends)
        self.assertIn("Up to 16 KiB sends directly; larger files need Me → Large files (up to 100 MiB).", friends)
        picker_flow = friends[friends.index("function openAttachmentBrowser("):friends.index("function openPrivateSafetyCode(")]
        self.assertIn("root.service.pickAttachment(folderMode", picker_flow)
        self.assertIn("root.hostWidget.close()", picker_flow)
        self.assertIn("root.hostWidget.open()", picker_flow)
        self.assertNotIn("attachmentDialogLaunchTimer", friends)
        self.assertNotIn("onRejected:", friends)
        self.assertIn("id: modernPanelLoader\n        active: true", bar)
        self.assertNotIn("FolderListModel", friends)

    def test_private_groups_remain_visible_before_first_message(self):
        friends = read("FriendsPanelV3.qml")
        start = friends.index("function conversationGroups()")
        end = friends.index("function selectedFriend()", start)
        body = friends[start:end]
        self.assertIn("root.groupsList()", body)
        self.assertIn("out.push(group)", body)
        self.assertNotIn("groupHasHistory(group.id)", body)
        self.assertNotIn("if (!active) continue", body)

    def test_build_network_is_lazy_loaded(self):
        bar = read("BarWidget.qml")
        start = bar.index("id: buildPanelLoader")
        body = bar[start:]
        self.assertIn("active: root.buildCardOpen", body)
        self.assertIn('source: Qt.resolvedUrl("BuildNetworkPanelV3.qml")', body)
        self.assertNotIn("active: true", body)

    def test_generic_popup_close_dismisses_friends_and_build(self):
        bar = read("BarWidget.qml")
        start = bar.index("function close()")
        end = bar.index("function toggleBuildCard()", start)
        close_body = bar[start:end]
        self.assertIn("cardOpen = false", close_body)
        self.assertIn("buildCardOpen = false", close_body)

    def test_full_status_refresh_runs_only_while_friends_ui_is_open(self):
        service = read("Service.qml")
        bar = read("BarWidget.qml")
        timer = service[service.index("id: statusRefreshTimer"):service.index("// Retry one previously saved private message")]
        self.assertIn("property bool uiOpen: false", service)
        self.assertIn("function setUiOpen(open)", service)
        self.assertIn("if (next) root.refresh()", service)
        self.assertIn("interval: 8000", timer)
        self.assertIn("running: root.uiOpen", timer)
        self.assertIn("onCardOpenChanged: syncServiceVisibility()", bar)
        self.assertIn("onBuildCardOpenChanged: syncServiceVisibility()", bar)
        self.assertIn("root.service.setUiOpen(root.opened)", bar)
        retry_timer = service[service.index("// Retry one previously saved private message"):service.index("// Event poll timer")]
        event_timer = service[service.index("// Event poll timer"):service.index("Component.onCompleted")]
        self.assertIn("running: !root.uiOnlyFallback", retry_timer)
        self.assertIn("running: !root.uiOnlyFallback", event_timer)
        self.assertIn("property bool uiOnlyFallback: false", service)

    def test_async_send_and_create_failures_preserve_user_drafts(self):
        friends = read("FriendsPanelV3.qml")
        service = read("Service.qml")
        build = read("BuildNetworkPanelV3.qml")
        build_service = read("BuildNetworkService.qml")
        circle_send = friends[friends.index("function sendCommunity()"):friends.index("function filteredWorld()")]
        create_submit = build[build.index("function submitCreate()"):build.index("function kindLabel(")]
        self.assertIn("if (callback) callback(result.ok === true, result)", service)
        self.assertIn("if (ok && root.communityDraft.trim() === text)", circle_send)
        self.assertIn("if (ok && root.communityDraft.trim() === text) root.communityDraft = \"\"", circle_send)
        self.assertIn("onCreateResult", build)
        self.assertIn("if (ok && submittedSnapshot === root.createDraftSnapshot()) root.clearDrafts()", build)
        self.assertNotIn("root.clearDrafts()", create_submit)
        self.assertIn("if (root.createSubmitting) return", create_submit)
        self.assertIn("submittedSnapshot: submittedSnapshot || \"\"", build_service)
        self.assertIn("root.createResult(ok, message, next.submittedSnapshot)", build_service)
        send = friends[friends.index("function sendMessage()"):friends.index("function sendCommunity()")]
        conversation = friends[friends.index("function conversationMessages()"):friends.index("function lastMessagePreview(")]
        self.assertIn('sendState: "Sending…"', send)
        self.assertIn("root.optimisticMessages = root.optimisticMessages.concat([optimistic])", send)
        self.assertIn('media: media ? [{ url: media, kind: "link" }] : []', send)
        self.assertIn("root.optimisticMessages", conversation)
        self.assertIn('var sentId = local.serverMessageId ? String(local.serverMessageId) : ""', conversation)
        self.assertIn("savedById[sentId]", conversation)

    def test_world_empty_state_invites_and_explains_connectivity(self):
        friends = read("FriendsPanelV3.qml")
        world = friends.split("// WORLD", 1)[1].split("// CIRCLES", 1)[0]
        self.assertIn('text: "Copy invite"', world)
        self.assertIn('onClicked: root.copyInvite()', world)
        self.assertIn('root.service.refreshGlobal()', world)
        self.assertIn("root.worldEmptyMessage()", world)
        self.assertIn('root.globalConnectionText === "Checking relays"', friends)
        self.assertIn('root.globalConnectionText === "Relay check failed"', friends)
        self.assertIn('root.globalConnectionText === "Reconnecting"', friends)
        self.assertIn("does not affect who you can see", friends)
        presence = friends.split("function selfPresenceIsLive()", 1)[1].split("function worldEmptyMessage()", 1)[0]
        self.assertIn("root.worldRelaysConnected", presence)
        self.assertIn("root.worldLastPublish", presence)

    def test_conversations_remain_listed_from_persistent_dm_memory(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn('readonly property var memory: service && service.globalMemory', friends)
        friend_list = friends[friends.index("function friendsList()"):friends.index("function incomingFriendRequests()")]
        self.assertIn("var ownKey = root.profile && root.profile.public_key", friend_list)
        self.assertIn("for (var i = root.messages.length - 1; i >= 0; i--)", friend_list)
        self.assertIn("savedItem.saved_history_only = true", friend_list)
        self.assertIn("function directHasConversationRecord(publicKey)", friends)
        self.assertIn("root.directHasConversationRecord(friend.public_key)", friends)
        self.assertIn("Older chat history is missing on this device", friends)
        engine = read("bin/omarchy-friends")
        self.assertIn("is_message_history", engine)
        self.assertIn("MAX_REMOTE_ATTACHMENT_BYTES = 100 * 1024 * 1024", engine)
        self.assertIn("MAX_RELAY_DM_MESSAGES = 500", engine)

    def test_message_views_use_cached_per_conversation_index(self):
        friends = read("FriendsPanelV3.qml")
        self.assertIn("function rebuildMessageIndex()", friends)
        self.assertIn("onMessagesChanged: {", friends)
        self.assertIn("onProfileChanged: {", friends)
        self.assertIn("root.rebuildMessageSearchIndex()", friends)
        self.assertNotIn("ensureMessageIndex()", friends)
        self.assertIn("root.messagesByConversation = byConversation", friends)
        self.assertIn("root.latestMessageIndices = lastIndex", friends)
        conversation = friends[friends.index("function conversationMessages()"):friends.index("function lastMessagePreview(")]
        self.assertIn("root.messagesForConversation(historyKind, historyId)", conversation)
        self.assertIn('friend.legacy_archive ? "unlinked" : "friend"', conversation)

    def test_chat_list_bindings_only_read_a_search_index_built_by_change_handlers(self):
        friends = read("FriendsPanelV3.qml")
        getter = friends[friends.index("function messageSearchIndex()") : friends.index("function latestMessageMatchForFriend(")]
        builder = friends[friends.index("function rebuildMessageSearchIndex()") : friends.index("function messageSearchIndex()")]
        friend_rows = friends[friends.index("function conversationFriends()") : friends.index("function buildConversationFriends()")]
        group_rows = friends[friends.index("function conversationGroups()") : friends.index("function buildConversationGroups()")]
        self.assertIn("return root.indexedSearchMatches", getter)
        self.assertNotRegex(getter, r"root\.indexedSearch\w*\s*=")
        self.assertIn("root.indexedSearchMatches = matches", builder)
        self.assertIn("return root.buildConversationFriends()", friend_rows)
        self.assertIn("return root.buildConversationGroups()", group_rows)
        self.assertIn("function rebuildConversationRows()", friends)
        self.assertIn("onServiceStatusRevisionChanged:", friends)
        self.assertIn("Qt.callLater(root.rebuildConversationRows)", friends)
        self.assertIn("onChatQueryChanged:", friends)
        self.assertIn("onGlobalSearchResultsChanged()", friends)

    def test_v2_fallback_scopes_drafts_and_clears_only_after_success(self):
        v2 = read("FriendsPanelV2.qml")
        self.assertIn('root.prepareDraftForConversation("friend:"', v2)
        self.assertIn('root.prepareDraftForConversation("group:"', v2)
        self.assertIn("if (!ok || root.draftConversationKey !== conversationKey) return", v2)
        self.assertIn("if (ok && root.communityDraft.trim() === text)", v2)
        self.assertIn("if (!ok || root.groupNameDraft.trim() !== name", v2)

    def test_primary_glass_actions_are_keyboard_reachable(self):
        for path in ("GlassButton.qml", "GlassNavItem.qml", "GlassPill.qml"):
            text = read(path)
            self.assertIn("activeFocusOnTab: root.enabled || root.activeFocus", text, path)
            self.assertIn("Keys.onPressed", text, path)
            self.assertIn("Qt.Key_Return", text, path)
            self.assertIn("Qt.Key_Enter", text, path)
            self.assertIn("Qt.Key_Space", text, path)
            self.assertIn("root.forceActiveFocus()", text, path)
            self.assertIn("Accessible.role: Accessible.Button", text, path)
            self.assertIn("Accessible.name:", text, path)

    def test_popup_surfaces_prime_keyboard_focus_for_every_fallback(self):
        targets = {
            "FriendsPanelV3.qml": "chatsNav",
            "FriendsPanelV2.qml": "chatsNav",
            "Panel.qml": "keyCatcher",
            "BuildNetworkPanelV3.qml": "syncButton",
        }
        for path, target in targets.items():
            panel = read(path)
            self.assertTrue(panel.startswith("import QtQuick"), path)
            self.assertIn("KeyboardPanel {", panel, path)
            self.assertIn(f"focusTarget: {target}", panel, path)
            self.assertNotIn("triggerMode:", panel, path)
            self.assertNotRegex(panel, r"(?m)^    Keys\.onEscapePressed:", path)
            if path == "Panel.qml":
                self.assertIn("Keys.onPressed: function(event)", panel)
            else:
                self.assertIn(f"id: {target}\n                            Keys.onEscapePressed:", panel, path)

    def test_keyboard_focus_has_visible_feedback(self):
        button = read("GlassButton.qml")
        nav = read("GlassNavItem.qml")
        pill = read("GlassPill.qml")
        self.assertIn("root.activeFocus", button)
        self.assertIn("root.activeFocus", nav)
        self.assertIn("root.activeFocus", pill)
        self.assertIn("visible: root.activeFocus", button)
        self.assertIn("border.width: 2", button)
        self.assertIn("border.color: root.coolTint", button)
        self.assertIn("border.width: root.activeFocus ? 2 : 1", pill)

    def test_build_tabs_use_keyboard_accessible_shared_control(self):
        build = read("BuildNetworkPanelV3.qml")
        start = build.index('{ id: "discover", label: "Discover" }')
        end = build.index('visible: root.notice !== ""', start)
        tab_bar = build[start:end]
        self.assertIn("GlassPill {", tab_bar)
        self.assertIn("text: modelData.label", tab_bar)
        self.assertIn("onClicked: root.tab = modelData.id", tab_bar)
        self.assertNotIn("TapHandler { onTapped: root.tab = modelData.id }", tab_bar)

    def test_helper_availability_inputs_are_labeled(self):
        build = read("BuildNetworkPanelV3.qml")
        self.assertIn('placeholderText: "Skills, tools or topics"', build)
        self.assertIn('Accessible.name: "Skills, tools or topics"', build)
        self.assertIn('placeholderText: "Short note for other builders"', build)
        self.assertIn('Accessible.name: "Short note for other builders"', build)
        avail = build.split("id: availabilityColumn", 1)[1].split("Text { text: \"Availability expires automatically.\"", 1)[0]
        self.assertIn("TextField {", avail)
        self.assertNotIn("TextInput {", avail)

    def test_shared_glass_field_names_both_editors_accessibly(self):
        field = read("GlassField.qml")
        accessible_name = 'Accessible.name: root.accessibleName || root.placeholder || "Text field"'
        self.assertIn('property string accessibleName: ""', field)
        self.assertEqual(field.count(accessible_name), 2)
        single_line = field.split("TextInput {", 1)[1].split("TextArea {", 1)[0]
        multiline = field.split("TextArea {", 1)[1]
        self.assertIn(accessible_name, single_line)
        self.assertIn(accessible_name, multiline)

    def test_no_one_shot_write_patchers_remain(self):
        forbidden = (
            ".github/workflows/request-management-patcher.yml",
            "scripts/_request_patch.py",
            ".github/workflows/v3-safety-patcher.yml",
            "scripts/_v3_safety_patch.py",
            ".github/workflows/final-ux-patcher.yml",
            "scripts/_final_ux_patch.py",
            ".github/workflows/request-layout-fixer.yml",
            "scripts/_request_layout_fix.py",
            ".github/workflows/group-visibility-fixer.yml",
            "scripts/_group_visibility_fix.py",
            ".github/workflows/final-build-tabs-patch.yml",
            "scripts/_final_build_tabs_patch.py",
            ".github/workflows/fix-multirelay-listener.yml",
            "scripts/_fix_multirelay_listener.py",
        )
        for path in forbidden:
            self.assertFalse((ROOT / path).exists(), path)


if __name__ == "__main__":
    unittest.main()

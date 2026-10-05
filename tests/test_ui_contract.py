from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ModernFriendsUiContractTests(unittest.TestCase):
    def read(self, path: str) -> str:
        return (ROOT / path).read_text(encoding="utf-8")

    def test_v3_shell_is_primary_with_v2_and_legacy_fallbacks(self):
        bar = self.read("BarWidget.qml")
        self.assertIn('FriendsPanelV3.qml', bar)
        self.assertIn('FriendsPanelV2.qml', bar)
        self.assertIn('Panel.qml', bar)
        self.assertIn('modernPanelLoader.status === Loader.Error', bar)
        self.assertIn('compatibilityPanelLoader.status === Loader.Error', bar)
        self.assertIn('function openBuildTab', bar)
        self.assertIn('BuildNetworkPanelV3.qml', bar)

    def test_v3_shell_has_first_class_product_navigation(self):
        panel = self.read("FriendsPanelV3.qml")
        for label in ("Chats", "Requests", "World", "Circles", "Build", "Me"):
            self.assertIn(f'text: "{label}"', panel)
        for shortcut in ("New chat", "Ask help", "Setup"):
            self.assertIn(f'text: "{shortcut}"', panel)
        self.assertIn('root.openBuild("discover")', panel)
        self.assertIn('root.openBuild("share")', panel)
        self.assertIn('root.openBuild("help")', panel)

    def test_chat_header_and_empty_state_keep_copy_compact(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn('text: "Opened conversations"', panel)
        self.assertIn('"Pick a friend to start chatting."', panel)
        self.assertIn('chatListEmptyState() === "empty"', panel)
        self.assertIn('chatListEmptyState() === "error"', panel)
        self.assertIn('"Loading saved conversations…"', panel)
        self.assertIn('"No chats yet"', panel)
        self.assertIn('visible: root.selectedFriend() !== null && !root.selectedFriend().legacy_archive; width: visible ? implicitWidth : 0;', panel)
        self.assertIn('visible: (root.selectedFriend() !== null && !root.selectedFriend().legacy_archive) || root.selectedGroup() !== null; width: visible ? implicitWidth : 0;', panel)
        self.assertIn('id: chatMoreButton', panel)
        chat = panel.split('id: conversationHeader', 1)[1].split('id: conversationDivider', 1)[0]
        self.assertIn('id: focusButton', chat)
        self.assertIn('parent.width - Style.space(58) - focusButton.width - olderHistoryButton.width - chatMoreButton.width', chat)
        self.assertNotIn('buildTogetherButton', chat)

    def test_chat_composer_stays_inside_chat_surface(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn("id: chatHeaderRow", panel)
        self.assertIn("id: conversationDivider", panel)
        self.assertIn("id: messageComposer", panel)
        self.assertIn(
            "parent.height - conversationHeader.height - conversationDivider.height - messageComposer.height - parent.spacing * 3",
            panel,
        )
        self.assertNotIn('Math.max(Style.space(72), parent.height - conversationHeader.height', panel)

    def test_v3_loader_connections_are_nested_under_item(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn(
            "// KeyboardPanel's default contentItem accepts QQuickItems only.\n"
            "        // Connections is a QObject, so keep it under a real Item",
            panel,
        )
        self.assertIn("Connections {", panel.split("// KeyboardPanel's default contentItem", 1)[1].split("function updateCommunityMessageItems", 1)[0])

    def test_v3_service_change_handler_is_unique(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertEqual(
            panel.count("onServiceChanged:"),
            1,
            "duplicate service handlers make the V3 Loader fail and hide Chats",
        )

    def test_requests_are_not_mixed_into_chat_list_and_are_manageable(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        chats = panel.split("// CHATS:", 1)[1].split("// REQUESTS", 1)[0]
        requests = panel.split("// REQUESTS", 1)[1].split("// WORLD", 1)[0]
        self.assertNotIn("incomingFriendRequests()", chats)
        self.assertIn("incomingFriendRequests()", requests)
        self.assertIn("sentFriendRequests()", requests)
        self.assertIn('requestTab === "received"', requests)
        self.assertIn('requestTab === "sent"', requests)
        self.assertIn('text: "Accept"', requests)
        self.assertIn('text: "Decline"', requests)
        self.assertIn('text: "Cancel"', requests)
        self.assertIn('function declineFriendRequest', panel)
        self.assertIn('function cancelFriendRequest', panel)
        self.assertIn('root.service.declineFriendRequest(pingId)', panel)
        self.assertIn('root.service.cancelFriendRequest(publicKey)', panel)
        self.assertIn('function declineFriendRequest(pingId)', service)
        self.assertIn('function cancelFriendRequest(publicKey)', service)
        self.assertIn('"decline-friend"', service)
        self.assertIn('"cancel-friend"', service)
        self.assertNotIn('[root.service.binPath, "decline-friend"', panel)
        self.assertNotIn('[root.service.binPath, "cancel-friend"', panel)

    def test_chats_only_show_opened_conversations_and_have_separate_picker(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn("function conversationFriends()", panel)
        self.assertIn("friend.legacy_archive === true || root.directHasConversationRecord(friend.public_key) || root.selectedFriendKey === friend.public_key", panel)
        self.assertIn("Recovered unlinked messages use the owner's key as a local", panel)
        conversation_record = panel[panel.index("function directHasConversationRecord("):panel.index("function groupHasHistory(")]
        self.assertIn("Number(item.dms_sent || 0) > 0", conversation_record)
        self.assertIn("Number(item.dms_received || 0) > 0", conversation_record)
        self.assertNotIn('friend.status === "friends" || root.directHasConversationRecord', panel)
        self.assertIn("Full friend list lives here instead of cluttering Chats", panel)
        self.assertIn('text: "New chat"', panel)
        self.assertIn('text: "Create private group"', panel)

    def test_saved_chat_rows_recover_from_durable_message_counts(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        self.assertIn("service.globalMessageCounts", panel)
        self.assertIn('for (var conversationKey in root.messageCounts)', panel)
        self.assertIn('conversationKey.indexOf("friend:") !== 0', panel)
        self.assertIn('root.messageCounts["friend:" + String(publicKey || "")]', panel)
        self.assertIn("onMessageCountsChanged:", panel)
        self.assertIn("Qt.callLater(restoreConversationAfterStatusRefresh)", panel)
        self.assertIn("ServiceModern {", panel)
        self.assertIn("uiOnlyFallback: true", panel)
        self.assertIn("property bool uiOnlyFallback: false", service)
        self.assertIn("running: !root.uiOnlyFallback", service)
        self.assertIn("function retainKnownConversationCounts(incoming)", service)
        self.assertIn("Math.max(Number(retained[key] || 0), Math.floor(count))", service)
        self.assertIn("root.retainKnownConversationCounts(data.global_message_counts)", service)

    def test_missing_dm_history_offers_explicit_relay_recovery(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn("function selectedFriendHistoryMissing()", panel)
        self.assertIn('text: root.syncingPrivateHistory ? "Checking inbox relays…" : "Check inbox relays for history"', panel)
        self.assertIn("root.service.syncPrivateHistory(function(ok)", panel)
        self.assertIn("function syncPrivateHistory(callback)", service)
        self.assertIn('"sync-private-history"', service)
        self.assertIn('elif command == "sync-private-history":', engine)
        self.assertIn('"limit": MAX_RELAY_DM_MESSAGES', engine)
        self.assertIn('"global_private_history_cursors": global_state.get("private_history_cursors", {})', engine)
        self.assertIn('function hasMorePrivateHistoryPages(publicKey)', panel)
        self.assertIn('id: olderHistoryButton', panel)
        self.assertIn('onClicked: root.syncEarlierMessages()', panel)
        self.assertIn('if until:\n                event_filter["until"]', engine)

    def test_people_safety_actions_survive_the_v3_cleanup(self):
        panel = self.read("FriendsPanelV3.qml")
        legacy_panel = self.read("Panel.qml")
        service = self.read("Service.qml")
        world = panel.split("// WORLD", 1)[1].split("// CIRCLES", 1)[0]
        chats = panel.split("// CHATS:", 1)[1].split("// REQUESTS", 1)[0]
        self.assertIn("function blockPeer(peer)", panel)
        self.assertIn("function reportPeer(peer)", panel)
        self.assertIn("root.service.blockGlobal(peer.public_key)", panel)
        self.assertIn("root.reportUrl", panel)
        self.assertIn('text: "Block"', world)
        self.assertIn('text: "Report"', world)
        self.assertIn('text: "Close chat"', panel)
        self.assertIn('text: "Report"', panel[panel.index("id: chatActionsMenu"):panel.index("Dialog {\n            id: forwardDialog")])
        self.assertIn('text: "⋯"', world)
        self.assertIn("function blockGlobal(publicKey)", service)

        legacy_block_action = legacy_panel.split("root.service.blockGlobal(modelData.public_key)", 1)[0][-500:]
        self.assertIn('text: "Block"', legacy_block_action)
        self.assertNotIn('text: "Hide"', legacy_panel)

    def test_unblock_triggers_world_refresh_and_chat_drafts_do_not_cross_recipients(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        unblock = service.split("function unblockGlobal(publicKey)", 1)[1].split("function dismissNudge", 1)[0]
        self.assertIn("if (result.ok === true) root.refreshGlobal()", unblock)
        self.assertIn("function prepareDraftForConversation(key)", panel)
        self.assertIn('root.prepareDraftForConversation("friend:"', panel)
        self.assertIn('root.prepareDraftForConversation("group:"', panel)
        self.assertIn('root.draftConversationKey === key && root.draftAccountKey === accountKey', panel)
        self.assertIn('root.messageDraft = draft.text || ""', panel)

    def test_failed_private_sends_and_group_creation_preserve_user_input(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        send = panel.split("function sendMessage()", 1)[1].split("function sendCommunity()", 1)[0]
        create_group = panel.split("function createGroup()", 1)[1].split("function openProfile()", 1)[0]
        self.assertIn("function clearSentDraft(ok)", send)
        self.assertNotIn("if (root.sendingMessage) return", send)
        self.assertIn("root.pendingSendCount += 1", send)
        self.assertIn("root.pendingSendCount = Math.max(0, root.pendingSendCount - 1)", send)
        self.assertIn('item.sendState = "Not sent · message kept here"', send)
        self.assertIn("var serverMessageId = result && result.message_id ? String(result.message_id) : \"\"", send)
        self.assertIn("id: serverMessageId", send)
        self.assertIn('sendState: ok ? "Sent" : (result.send_state || "Unconfirmed · retry")', send)
        self.assertIn("if (serverMessageId)", send)
        self.assertIn("!root.attachmentDraftPath", send)
        self.assertIn("else if (canRestoreDraft)", send)
        self.assertIn('var sentId = local.serverMessageId ? String(local.serverMessageId) : ""', panel)
        self.assertIn("if (sentId && savedById[sentId] && !matchedSavedIds[sentId])", panel)
        self.assertIn("root.messageDraft = \"\"", send)
        draft_callback = send.split("function clearSentDraft(ok)", 1)[1].split("if (group) root.service.sendGroupMessage", 1)[0]
        self.assertIn('root.showNotice("Message was not confirmed; your draft was restored")', draft_callback)
        self.assertIn('else root.showNotice("Message was not confirmed; check the chat before retrying")', draft_callback)
        self.assertIn('root.editingMessage ? (root.savingMessageEdit ? "Saving…" : "Save") : "Send"', panel)
        self.assertIn('!!root.messageDraft.trim() || (!root.editingMessage && (!!root.mediaDraft.trim() || !!root.attachmentDraftPath))', panel)
        self.assertIn("root.service.sendGroupMessage(group.id, text, media, clearSentDraft, attachmentPath, attachmentIsFolder, reply)", send)
        self.assertIn("root.service.sendDm(friend.public_key, text, media, clearSentDraft, attachmentPath, attachmentIsFolder, reply)", send)
        self.assertIn("function retryPendingMessages()", service)
        self.assertIn('[root.binPath, "retry-pending-messages"]', service)
        self.assertIn("root.retryingPendingMessages", service)
        self.assertIn("interval: 5000", service)
        self.assertIn('icon: "📎"; accessibleName: "Attach a file, folder, or link"', panel)
        self.assertNotIn('text: "Link"; icon: "＋"', panel)
        self.assertNotIn('text: "File"; icon: "↥"', panel)
        self.assertNotIn('text: "Folder"; icon: "▱"', panel)
        self.assertIn('MenuItem { text: "Choose file…"; onTriggered: root.openAttachmentBrowser(false) }', panel)
        self.assertIn('MenuItem { text: "Choose folder…"; onTriggered: root.openAttachmentBrowser(true) }', panel)
        message_actions = panel[panel.index("id: messageActionMenu"):panel.index("Dialog {\n            id: forwardDialog")]
        self.assertIn('text: "↻ Retry send"', message_actions)
        self.assertIn('visible: modelData.retryable === true', message_actions)
        self.assertIn('retryPrivateMessage(messageDelegate.modelData.id)', message_actions)
        options = panel[panel.index("id: messageOptionsButton"):panel.index("Menu {\n                                                        id: messageActionMenu")]
        self.assertIn('anchors.left: modelData.incoming ? bubble.right : undefined', options)
        self.assertIn('anchors.right: modelData.incoming ? undefined : bubble.left', options)
        self.assertIn('anchors.verticalCenter: bubble.verticalCenter', options)
        self.assertNotIn('anchors.top: bubble.top', options)
        self.assertIn('layerNamespace: "omarchy-friends"', panel)
        self.assertNotIn('FileDialog {', panel)
        self.assertNotIn('FolderDialog {', panel)
        self.assertNotIn('attachmentDialogLaunchTimer', panel)
        picker_command = self.read("bin/omarchy-friends")
        self.assertIn('"pick-attachment"', picker_command)
        self.assertIn('"directory": dbus.Boolean(folder_mode)', picker_command)
        self.assertIn('path_keyword="signal_path"', picker_command)
        self.assertNotIn("path_namespace=", picker_command)
        self.assertNotIn('FolderListModel', panel)
        self.assertNotIn('id: attachmentBrowserOverlay', panel)
        self.assertIn('parent: contentArea\n            x: Math.max(Style.space(8), Math.min(contentArea.width - width - Style.space(8), attachmentButton.mapToItem(contentArea, 0, 0).x))', panel)
        self.assertIn('attachmentButton.mapToItem(contentArea, 0, attachmentButton.height).y', panel)
        self.assertNotIn('listAttachmentDirectory', service)
        self.assertNotIn('"browse-files"', service)
        self.assertIn('text: "Share a link…"', panel)
        self.assertIn('Paste or type the link in the message box', panel)
        self.assertNotIn('root.mediaComposerOpen', panel)
        self.assertNotIn('placeholder: "Optional https:// link"', panel)
        composer = panel.split('id: messageComposer', 1)[1].split('// REQUESTS', 1)[0]
        self.assertNotIn('Optional https:// link', composer)
        self.assertIn('accessibleName: "Attach a file, folder, or link"', composer)
        self.assertIn('"save-attachment"', self.read("bin/omarchy-friends"))
        self.assertIn("root.service.createGroup(name, selectedMembers, function(ok)", create_group)
        self.assertIn("if (root.creatingGroup) return", create_group)
        self.assertIn("root.creatingGroup = false", create_group)
        self.assertIn("if (!ok || root.groupNameDraft.trim() !== name", create_group)
        for method, fallback in (("sendDm", "Private message sent"), ("sendGroupMessage", "Group message could not be sent"), ("createGroup", "Group could not be created")):
            block = service.split(f"function {method}(", 1)[1].split("\n    function ", 1)[0]
            self.assertIn(f'root.reportResult(output, "{fallback}")', block)
            self.assertIn("if (callback) callback(result.ok === true, result)", block)

    def test_private_chat_supports_threaded_replies_without_draft_leakage(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertNotIn("selectByMouse:", panel)
        self.assertIn('text: "↩ Reply"', panel)
        self.assertIn('text: root.replyDraft ? "Replying to "', panel)
        self.assertIn("reply_to: reply", panel)
        self.assertIn("reply_to: replyTo || null", service)
        self.assertIn('reply_to=reply["id"] if reply else ""', engine)
        self.assertIn("reply is no longer available in this conversation", engine)
        self.assertIn('"react-message"', service)

    def test_forwarding_requires_a_target_and_uses_existing_encrypted_send_paths(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        self.assertIn('text: "Forward…"', panel)
        self.assertIn('function beginForward(message)', panel)
        self.assertIn('function forwardTargets()', panel)
        self.assertIn('root.service.forwardMessage(root.forwardDraft.messageId, target.kind, target.id, onForwarded)', panel)
        self.assertIn('"forward-message", messageId || "", targetKind || "", targetId || ""', service)
        self.assertIn('Text, media links and attachments are shared.', panel)
        self.assertIn('function sendDm(publicKey, text, mediaUrl, callback', service)
        self.assertIn('function sendGroupMessage(groupId, text, mediaUrl, callback', service)

    def test_private_chat_exposes_author_checked_delete_for_everyone(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('text: "Delete for everyone"', panel)
        self.assertIn('!modelData.incoming', panel)
        self.assertIn("root.service.deleteMessage(message.id)", panel)
        self.assertIn('function deleteMessage(messageId)', service)
        self.assertIn('"delete-message"', service)
        self.assertIn('elif command == "delete-message"', engine)
        self.assertIn('"type": "delete"', engine)

    def test_message_actions_live_in_compact_three_dot_menu(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('text: "⋯"', panel)
        self.assertIn('accessibleName: "Message options"', panel)
        self.assertIn('visible: !modelData.deleted && String(modelData.id || "").indexOf("local_") !== 0', panel)
        self.assertIn('text: "Delete for me"', panel)
        self.assertIn('text: "Delete for everyone"', panel)
        self.assertIn('text: "↩ Reply"', panel)
        self.assertIn('onLongPressed: messageActionMenu.popup()', panel)
        self.assertIn('button === Qt.RightButton', panel)
        self.assertNotIn('text: "👍 Like"', panel)
        self.assertNotIn('title: "React"', panel)
        self.assertNotIn('id: reactionActions', panel)
        self.assertNotIn('id: deleteAction', panel)
        self.assertIn('function deleteMessageForMe(messageId)', service)
        self.assertIn('"delete-message-for-me"', engine)
        self.assertIn('"locally_hidden_message_ids"', engine)

    def test_popups_use_item_local_coordinates(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn("parent: messageDelegate\n                                                        x: bubble.x + bubble.width - width", panel)
        self.assertIn("parent: contentArea\n            x: Math.max(Style.space(8), Math.min(contentArea.width - width - Style.space(8), attachmentButton.mapToItem(contentArea, 0, 0).x))", panel)
        self.assertIn("parent: chatMoreButton.parent\n            x: chatMoreButton.x", panel)
        self.assertEqual(panel.count("attachmentButton.mapToItem(contentArea,"), 2)
        self.assertIn('sequences: ["Escape"]', panel)
        self.assertIn("onActivated: root.close()", panel)

    def test_chat_dialog_cards_center_in_content_area_without_window_anchors(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertGreaterEqual(panel.count("x: (parent.width - width) / 2"), 2)
        self.assertGreaterEqual(panel.count("y: (parent.height - height) / 2"), 2)
        self.assertNotIn("anchors.centerIn: parent", panel[panel.index("// New-chat picker"):panel.index("Menu {\n            id: attachmentMenu")])

    def test_text_edit_action_uses_compose_and_has_engine_age_and_author_guards(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('text: "Edit message"', panel)
        self.assertIn('function beginMessageEdit(message)', panel)
        self.assertIn('function editMessage(messageId, text, callback)', service)
        self.assertIn('"edit-message"', engine)
        self.assertIn('def edit_message(self, target_id, text)', engine)
        self.assertIn('MAX_MESSAGE_EDIT_AGE = 15 * 60', engine)
        self.assertIn('target.get("incoming")', engine)
        self.assertIn('"edited"', engine)

    def test_read_receipts_are_opt_in_and_private_chat_ui_shows_confirmed_receipts(self):
        panel = self.read("FriendsPanelV3.qml")
        engine = self.read("bin/omarchy-friends")
        readme = self.read("README.md")
        self.assertIn('"share_read_receipts": False', engine)
        self.assertIn('text: "Read receipts"; active: root.profile.privacy && root.profile.privacy.share_read_receipts === true', panel)
        service = self.read("Service.qml")
        self.assertIn("var hasDueReadReceipt = false", service)
        self.assertIn("message.read_receipt_eligible === true", service)
        self.assertIn("read_receipts_attempted", service)
        self.assertIn('modelData.sendState === "Sent" ? "Sent · relay"', panel)
        self.assertIn("This local unread tracking is separate from the optional encrypted read receipts described above.", readme)
        self.assertNotIn("Friends does not publish read receipts", readme)
        self.assertIn('text: modelData.group_id ? "✓✓ Read by " + modelData.read_by.length : "✓✓ Read"', panel)
        self.assertIn('"type": "read_receipt"', engine)
        self.assertIn('def _apply_message_read_receipt(self, target_id, actor, group_id)', engine)
        self.assertIn('"read_receipt_eligible"', engine)

    def test_typing_indicators_are_friend_only_ephemeral_and_opt_out_controls_exist(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('text: "Typing indicators"; active: root.profile.privacy && root.profile.privacy.share_typing === true', panel)
        self.assertIn('"typing…"', panel)
        self.assertIn('onEdited: root.updateTypingSignal(text)', panel)
        self.assertIn('"send-typing"', engine)
        self.assertIn('"typing-status"', engine)
        self.assertIn('NIP59_EPHEMERAL_GIFT_WRAP_KIND', engine)
        self.assertIn('self._write_typing_cache(peers)', engine)
        start = engine.index('def _ingest_global_typing(')
        end = engine.index('def _empty_global_focus(', start)
        self.assertNotIn('global_state.setdefault("messages", []).append', engine[start:end])
        self.assertIn('function sendTyping(publicKey, state)', service)
        self.assertIn('function refreshTypingStatus()', service)
        self.assertIn('root.service.togglePrivacy("share_typing")', panel)
        fallback = self.read("FriendsPanelV2.qml")
        self.assertIn('onEdited: root.updateTypingSignal(text)', fallback)
        self.assertIn('root.service.setTypingPeer(key)', fallback)
        self.assertEqual(panel.count("onOpenChanged:"), 1)
        self.assertEqual(panel.count("onProfileChanged:"), 1)
        self.assertIn("} else root.stopTypingSignal()", panel)
        self.assertEqual(fallback.count("onOpenChanged:"), 1)
        self.assertIn("} else root.stopTypingSignal()", fallback)

    def test_chat_search_indexes_loaded_messages_in_memory_and_opens_matching_message(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn('placeholder: "Search chats and messages"', panel)
        self.assertIn("function messageSearchIndex()", panel)
        self.assertIn('root.indexedSearchMatches = matches', panel)
        self.assertIn("root.searchableMessageText(message).indexOf(query)", panel)
        self.assertIn('"friend:" + (message.conversation_key || message.public_key)', panel)
        self.assertIn('"group:" + message.group_id', panel)
        self.assertIn("if (!message || message.deleted) return \"\"", panel)
        self.assertIn("message.reply_to.text", panel)
        self.assertIn("attachments[j].name", panel)
        self.assertIn("root.openFriendSearchResult(modelData)", panel)
        self.assertIn("root.openGroupSearchResult(modelData)", panel)
        self.assertIn("root.scrollToSearchTarget)", panel)
        self.assertIn('String(modelData.id || "") === root.searchTargetMessageId', panel)
        self.assertIn("root.indexedSearchMessages === messages", panel)

    def test_chat_history_pages_older_messages_without_losing_scroll_anchor(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('command: [root.binPath, "status-ui"]', service)
        self.assertIn('root.service.loadConversationHistory(kind, identifier, root.service.activeHistoryNextOffset', panel)
        self.assertIn('root.service.canLoadEarlierMessages(', panel)
        self.assertIn('root.activeHistoryMessages = combined', service)
        self.assertIn('root.rebuildGlobalMessageCache()', service)
        self.assertIn('"status-ui"', engine)
        self.assertIn(': "Load earlier messages"', panel)
        self.assertIn("visible: root.hasEarlierMessages()", panel)
        self.assertIn('root.service.loadConversationHistory(historyKind, historyId, targetOffset', panel)
        self.assertIn('root.service.loadConversationHistory("group", root.selectedGroupId, targetOffset', panel)
        self.assertIn("messageScroller.contentHeight - oldHeight", panel)
        self.assertIn('[root.binPath, "search-messages", "-"]', service)
        self.assertIn('}, JSON.stringify(search))', service)
        self.assertIn('stdinEnabled: privateInputEnabled', service)
        self.assertIn('write(privateInput)', service)
        self.assertIn("property var activeSearchProcess: null", service)
        self.assertIn("previousSearchProcess.running = false", service)
        self.assertIn("return proc", service)

    def test_unlinked_saved_messages_have_a_read_only_recovery_archive(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('root.messagesByConversation["unlinked:local"]', panel)
        self.assertIn('handle: "Recovered messages"', panel)
        self.assertIn('"Recipient unavailable · saved on this device"', panel)
        self.assertIn('root.service.loadConversationHistory(historyKind, historyId, targetOffset', panel)
        self.assertIn('friend.legacy_archive ? "unlinked" : "friend"', panel)
        self.assertIn('root.selectedFriend().legacy_archive ? "Recovered archive is read-only"', panel)
        self.assertIn('These saved messages have no recipient record and are read-only', panel)
        self.assertIn('kind === "unlinked" ? "unlinked" : "friend"', service)
        self.assertIn('conversation_type == "unlinked"', engine)
        self.assertIn("conversation-index-version','2", engine)

    def test_pinned_conversations_are_local_and_sorted_ahead_of_recent_chats(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn("globalPinnedConversations", service)
        self.assertIn('root.service.setConversationPinned(kind, identifier', panel)
        self.assertIn('function isConversationPinned(kind, identifier)', panel)
        self.assertIn('text: root.isConversationPinned(root.selectedGroup() ? "group" : "friend"', panel)
        self.assertIn('root.isConversationPinned("group", modelData.id) ? "★ " : ""', panel)
        self.assertIn('root.isConversationPinned("friend", modelData.public_key) ? "★ " : ""', panel)
        self.assertIn('"global_pinned_conversations": list(global_state.get("pinned_conversations", []))', engine)
        self.assertIn('elif command == "pin-conversation"', engine)
        self.assertIn("MAX_PINNED_CONVERSATIONS = 20", engine)

    def test_muted_conversations_suppress_notifications_without_hiding_messages(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn("globalMutedConversations", service)
        self.assertIn('root.service.setConversationMuted(kind, identifier', panel)
        self.assertIn('text: root.isConversationMuted(root.selectedGroup() ? "group" : "friend"', panel)
        self.assertIn('"global_muted_conversations": list(global_state.get("muted_conversations", []))', engine)
        self.assertIn('elif command == "mute-conversation"', engine)
        self.assertIn('if notify and conversation_key not in global_state.get("muted_conversations", [])', engine)

    def test_chats_show_private_unread_counts_and_mark_only_local_state_read(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn("globalUnreadCounts", service)
        self.assertIn('root.service.markConversationRead("friend", root.selectedFriendKey)', panel)
        self.assertIn('root.service.markConversationRead("group", root.selectedGroupId)', panel)
        self.assertIn('function markConversationRead(kind, identifier)', service)
        mark_read_service = service.split('function markConversationRead(', 1)[1].split('\n    function ', 1)[0]
        self.assertIn('[root.binPath, "mark-read", kind || "", identifier || ""]', mark_read_service)
        self.assertIn('if (result.ok === true) root.refresh()', mark_read_service)
        self.assertIn('root.unreadCount("friend", modelData.public_key)', panel)
        self.assertIn('root.unreadCount("group", modelData.id)', panel)
        self.assertIn('"global_unread_counts": self._global_unread_counts()', engine)
        self.assertIn('elif command == "mark-read"', engine)
        mark_read = engine.split('elif command == "mark-read"', 1)[1].split('elif command == "set-blossom-server"', 1)[0]
        self.assertNotIn("publish", mark_read.lower())

    def test_world_cards_keep_one_clear_primary_connection_action(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn("Your profile is hidden from public discovery", panel)
        world = panel.split("// WORLD", 1)[1].split("// CIRCLES", 1)[0]
        self.assertIn('return "Message"', panel)
        self.assertIn('return "Connect"', panel)
        self.assertNotIn('text: "Wave"', world)
        self.assertNotIn('text: "Focus"', world)
        self.assertNotIn('text: "Build"', world)
        self.assertIn('id: personAction', world)
        for filter_name in ("All", "New", "Building", "Friends"):
            self.assertIn(f'text: "{filter_name}"', world)

    def test_circles_is_room_style_chat_and_profile_exposes_privacy(self):
        panel = self.read("FriendsPanelV3.qml")
        circles = panel.split("// CIRCLES", 1)[1].split("// PROFILE", 1)[0]
        profile = panel.split("// PROFILE / SETTINGS", 1)[1].split("// New-chat picker", 1)[0]
        self.assertIn('text: "Omarchy Circle"', circles)
        self.assertIn('placeholder: "Message the Circle…"', circles)
        self.assertIn("property var communityMessageItems: []", panel)
        self.assertIn("onCommunityChanged: updateCommunityMessageItems()", panel)
        self.assertIn("model: root.communityMessageItems", circles)
        self.assertIn("TextMetrics { id: circleTextMetrics", circles)
        self.assertNotIn("circleText.implicitWidth", circles)
        self.assertIn('text: "Privacy"', profile)
        self.assertNotIn("This is what other Omarchy users see when you choose to share it.", profile)
        self.assertIn('"World visibility on · turn off anytime"', profile)
        self.assertIn('"Hidden from World · turn on anytime"', profile)
        self.assertIn("Your profile is discoverable and its beacon is live.", panel)
        self.assertIn("No other visible Friends users are online on your reachable relays right now.", panel)
        self.assertIn("existing privacy choices are preserved", panel)
        self.assertIn("messages and chat history are never published here", panel)
        self.assertIn("relay operators may retain published data", profile)
        self.assertIn('readonly property string globalConnectionText:', panel)
        self.assertIn('"Presence not accepted"', panel)
        self.assertIn('"Reconnecting"', panel)
        self.assertIn('"Relay check failed"', panel)
        for privacy_key in ("share_global", "share_window", "share_music", "share_project", "share_interests", "share_room"):
            self.assertIn(f'root.service.togglePrivacy("{privacy_key}")', profile)

    def test_modern_shell_owns_stable_midnight_palette(self):
        panel = self.read("FriendsPanelV3.qml")
        expected = {
            'canvas': '#070b14',
            'ink': '#f3f5ff',
            'violet': '#7c6cff',
            'cyan': '#58d6ff',
        }
        for name, value in expected.items():
            self.assertIn(f'property color {name}: "{value}"', panel)
        self.assertNotIn('readonly property color canvas: Color.background', panel)

    def test_build_network_uses_same_product_palette(self):
        panel = self.read("BuildNetworkPanelV3.qml")
        self.assertIn('readonly property color fg: "#f3f5ff"', panel)
        self.assertIn('readonly property color bg: "#070b14"', panel)
        self.assertIn('readonly property color accent: "#7c6cff"', panel)

    def test_update_path_is_visible_explicit_and_never_background_write(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        modern_service = self.read("ServiceModern.qml")
        self.assertIn('visible: root.updateInfo.available', panel)
        self.assertIn('root.service.updatePlugin()', panel)
        self.assertIn('omarchy', service)
        self.assertIn('rescanPlugins', service)
        self.assertIn('manifestPath', service)
        self.assertIn('installedAfter !== expectedVersion', service)
        self.assertIn('plugin depot may still serve an older release', service)
        self.assertNotIn('Component.onCompleted: root.service.updatePlugin()', panel)
        self.assertNotIn('autoUpdate', modern_service)
        self.assertNotIn('Timer {', modern_service)
        self.assertIn('if (!output || output.trim() === "")', service)
        self.assertFalse((ROOT / "bin" / "omarchy-friends-auto-update").exists())

    def test_one_shot_write_capable_migration_helpers_are_removed(self):
        for path in (
            ROOT / ".github" / "workflows" / "request-management-patcher.yml",
            ROOT / "scripts" / "_request_patch.py",
            ROOT / ".github" / "workflows" / "v3-safety-patcher.yml",
            ROOT / "scripts" / "_v3_safety_patch.py",
        ):
            self.assertFalse(path.exists(), str(path))

    def test_shared_glass_primitives_exist(self):
        for path in (
            "GlassSurface.qml", "GlassPill.qml", "GlassButton.qml",
            "GlassField.qml", "GlassNavItem.qml", "GlassAvatar.qml",
        ):
            self.assertTrue((ROOT / path).is_file(), path)

    def test_chat_and_group_rows_are_keyboard_reachable(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertEqual(panel.count("Accessible.role: Accessible.Button"), 4)
        self.assertEqual(panel.count("Keys.onReturnPressed:"), 4)
        self.assertEqual(panel.count("Keys.onSpacePressed:"), 4)
        self.assertEqual(panel.count("activeFocusOnTab: true"), 4)

    def test_fallback_conversation_selection_remains_keyboard_reachable(self):
        for path, minimum_actions in (("FriendsPanelV2.qml", 3), ("Panel.qml", 4)):
            panel = self.read(path)
            self.assertGreaterEqual(panel.count("Keys.onReturnPressed:"), minimum_actions, path)
            self.assertGreaterEqual(panel.count("Keys.onSpacePressed:"), minimum_actions, path)
            self.assertGreaterEqual(panel.count("Accessible.role: Accessible.Button"), minimum_actions, path)

    def test_profile_has_explicit_feature_and_bug_feedback_paths(self):
        panel = self.read("FriendsPanelV3.qml")
        self.assertIn('text: "Suggest a feature"', panel)
        self.assertIn('text: "Report a bug"', panel)
        self.assertIn('labels=enhancement&title=Feature%20idea', panel)
        self.assertIn('labels=bug&title=Omarchy%20Friends%20bug', panel)

    def test_direct_chat_exposes_pairwise_safety_code_with_accurate_limitations(self):
        panel = self.read("FriendsPanelV3.qml")
        service = self.read("Service.qml")
        engine = self.read("bin/omarchy-friends")
        self.assertIn('text: "Verify security code"; visible: root.selectedFriend() !== null', panel)
        self.assertIn('root.service.getPrivateSafetyCode(friend.public_key', panel)
        self.assertIn('runAction([root.binPath, "safety-code", publicKey || ""]', service)
        self.assertIn('def derive_private_safety_code(first_public_key, second_public_key):', engine)
        self.assertIn("This fingerprint helps detect an identity-key mismatch. It does not provide forward secrecy or independently prove a person's identity.", panel)


if __name__ == "__main__":
    unittest.main()

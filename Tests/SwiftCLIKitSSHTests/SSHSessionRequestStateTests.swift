// SSHSessionRequestStateTests.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-07-14.

import Testing
import SwiftCLIKit
import NIOSSH
@testable import SwiftCLIKitSSH

@Suite("SSHSessionRequestState — PTY-allocation decides interactivity")
struct SSHSessionRequestStateTests {

    // MARK: - Pure decision core

    @Test("A fresh session is non-interactive with a default terminal size")
    func freshStateIsNonInteractive() {
        let state = SSHSessionRequestState()
        #expect(state.ptyAllocated == false)
        #expect(state.isInteractive == false)
        #expect(state.kind == .pending)
        #expect(state.terminalSize == TerminalSize(columns: 80, rows: 24))
    }

    @Test("A pty-req allocates a PTY and adopts its negotiated size")
    func pseudoTerminalRequestMakesInteractive() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 120, rows: 40)
        #expect(state.isInteractive == true)
        #expect(state.terminalSize == TerminalSize(columns: 120, rows: 40))
    }

    @Test("exec without a PTY stays non-interactive (ssh host cmd)")
    func execWithoutPTYStaysNonInteractive() {
        var state = SSHSessionRequestState()
        state.requestExec()
        #expect(state.isInteractive == false)
        #expect(state.kind == .exec)
    }

    @Test("exec with a PTY is interactive (ssh -tt host cmd)")
    func execWithPTYIsInteractive() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 100, rows: 30)
        state.requestExec()
        #expect(state.isInteractive == true)
        #expect(state.kind == .exec)
        #expect(state.terminalSize == TerminalSize(columns: 100, rows: 30))
    }

    @Test("shell without a PTY stays non-interactive (ssh -T host)")
    func shellWithoutPTYIsNonInteractive() {
        var state = SSHSessionRequestState()
        state.requestShell()
        #expect(state.isInteractive == false)
        #expect(state.kind == .shell)
    }

    @Test("shell with a PTY is interactive (ssh host)")
    func shellWithPTYIsInteractive() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 80, rows: 24)
        state.requestShell()
        #expect(state.isInteractive == true)
        #expect(state.kind == .shell)
    }

    @Test("A window-change updates the size but preserves interactivity")
    func windowChangeUpdatesSize() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 80, rows: 24)
        state.resize(columns: 200, rows: 50)
        #expect(state.terminalSize == TerminalSize(columns: 200, rows: 50))
        #expect(state.isInteractive == true)
    }

    @Test("A pty-req with non-positive dims still allocates but keeps the default size")
    func pixelOnlyPseudoTerminalKeepsDefaultSize() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 0, rows: 0)
        #expect(state.isInteractive == true)
        #expect(state.terminalSize == TerminalSize(columns: 80, rows: 24))
    }

    @Test("A window-change with non-positive dims is rejected, keeping the prior size")
    func nonPositiveResizeIsRejected() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 120, rows: 40)
        state.resize(columns: 0, rows: -5)
        #expect(state.terminalSize == TerminalSize(columns: 120, rows: 40))
    }

    // MARK: - NIOSSH channel-request adapter (synthetic requests)

    @Test("Applying a PseudoTerminalRequest allocates a PTY, does not establish")
    func applyPseudoTerminalRequest() {
        var state = SSHSessionRequestState()
        let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: false,
            term: "xterm-256color",
            terminalCharacterWidth: 120,
            terminalRowHeight: 40,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        let established = state.apply(pty)
        #expect(established == false)
        #expect(state.isInteractive == true)
        #expect(state.terminalSize == TerminalSize(columns: 120, rows: 40))
    }

    @Test("Applying a ShellRequest establishes the session")
    func applyShellRequest() {
        var state = SSHSessionRequestState()
        let established = state.apply(SSHChannelRequestEvent.ShellRequest(wantReply: false))
        #expect(established == true)
        #expect(state.kind == .shell)
    }

    @Test("Applying an ExecRequest establishes the session")
    func applyExecRequest() {
        var state = SSHSessionRequestState()
        let established = state.apply(
            SSHChannelRequestEvent.ExecRequest(command: "uptime", wantReply: false)
        )
        #expect(established == true)
        #expect(state.kind == .exec)
    }

    @Test("Applying a WindowChangeRequest resizes without establishing")
    func applyWindowChangeRequest() {
        var state = SSHSessionRequestState()
        state.allocatePseudoTerminal(columns: 80, rows: 24)
        let wc = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: 132,
            terminalRowHeight: 43,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        let established = state.apply(wc)
        #expect(established == false)
        #expect(state.terminalSize == TerminalSize(columns: 132, rows: 43))
    }

    @Test("Applying an unrelated event is ignored")
    func applyUnrelatedEventIsIgnored() {
        var state = SSHSessionRequestState()
        let established = state.apply(ChannelSuccessEvent())
        #expect(established == false)
        #expect(state == SSHSessionRequestState())
    }
}

import RiviSmartSortContract

/// Time for the runtime's timers, watchdogs and reconnect backoff. Injectable so tests never wait.
public protocol RiviClock: Sendable {
    /// Suspends for `milliseconds`. Throws `CancellationError` when the task is cancelled.
    func sleep(milliseconds: Int) async throws
}

public struct SystemClock: RiviClock {
    public init() {}

    public func sleep(milliseconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, milliseconds)) * 1_000_000)
    }
}

/// Named one-shot timers for the contract's StartTimer / CancelTimer commands. Starting a running
/// timer restarts it. A timer fires at most once per start.
@MainActor
final class NamedTimers {
    private var handles: [RiviTimer: (generation: Int, task: Task<Void, Never>)] = [:]
    private var generation = 0
    private let clock: RiviClock
    private let onFire: (RiviTimer, Int) -> Void

    init(clock: RiviClock, onFire: @escaping (RiviTimer, Int) -> Void) {
        self.clock = clock
        self.onFire = onFire
    }

    func start(_ timer: RiviTimer, ms: Int, epoch: Int) {
        cancel(.one(timer))
        generation += 1
        let mine = generation
        let task = Task { [clock, weak self] in
            do { try await clock.sleep(milliseconds: ms) } catch { return }
            guard let self, self.handles[timer]?.generation == mine else { return }
            self.handles[timer] = nil
            self.onFire(timer, epoch)
        }
        handles[timer] = (mine, task)
    }

    func cancel(_ target: TimerTarget) {
        switch target {
        case .all:
            for (_, handle) in handles { handle.task.cancel() }
            handles.removeAll()
        case .one(let timer):
            handles.removeValue(forKey: timer)?.task.cancel()
        }
    }

    var pending: [RiviTimer] { Array(handles.keys) }
}

/// A child of the current work that fails it after `ms` without a `kick()`.
@MainActor
final class Watchdog {
    private let clock: RiviClock
    private let ms: Int
    private var timer: Task<Void, Never>?
    private let onFire: () -> Void
    private(set) var fired = false

    init(clock: RiviClock, ms: Int = watchdogMs, onFire: @escaping () -> Void) {
        self.clock = clock
        self.ms = ms
        self.onFire = onFire
        arm()
    }

    /// Re-arms the full period, e.g. after a frame arrives.
    func kick() {
        guard !fired, timer != nil else { return }
        arm()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func arm() {
        timer?.cancel()
        timer = Task { [clock, ms, weak self] in
            do { try await clock.sleep(milliseconds: ms) } catch { return }
            guard let self, !Task.isCancelled, self.timer != nil else { return }
            self.timer = nil
            self.fired = true
            self.onFire()
        }
    }
}

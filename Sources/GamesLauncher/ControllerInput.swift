import GameController
import LauncherCore

@MainActor
final class ControllerInput {
    private let stickThreshold: Float = 0.5
    private let model: LauncherModel
    private var connectObserver: NSObjectProtocol?
    private var stickDirection = 0

    init(model: LauncherModel) {
        self.model = model
    }

    func start() {
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.configureConnected() }
        }
        configureConnected()
    }

    private func configureConnected() {
        GCController.controllers().forEach(configure)
    }

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        let model = model

        pad.dpad.left.pressedChangedHandler = onPress { model.moveLeft() }
        pad.dpad.right.pressedChangedHandler = onPress { model.moveRight() }
        pad.buttonA.pressedChangedHandler = onPress { Task { await model.confirm() } }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, _ in
            Task { @MainActor in self?.handleStick(x) }
        }
    }

    private func onPress(_ action: @escaping @MainActor @Sendable () -> Void) -> GCControllerButtonValueChangedHandler {
        { _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in action() }
        }
    }

    // Fires once per tilt: the stick has to return to center before moving again.
    private func handleStick(_ x: Float) {
        let direction = x > stickThreshold ? 1 : x < -stickThreshold ? -1 : 0
        defer { stickDirection = direction }
        guard direction != stickDirection else { return }
        if direction > 0 { model.moveRight() }
        if direction < 0 { model.moveLeft() }
    }
}

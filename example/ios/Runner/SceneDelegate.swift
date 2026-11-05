import Flutter
import UIKit
import sber_id

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      if SberIdPlugin.handleURL(context.url) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}

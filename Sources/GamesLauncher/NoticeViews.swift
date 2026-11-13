import SwiftUI

private let exampleConfig = """
{
  "games": [
    { "name": "Mi juego", "path": "~/Games/MiJuego" },
    {
      "name": "Otro juego",
      "path": "~/Games/OtroJuego",
      "command": "open --env LANG=es \\"Otro Juego.app\\""
    }
  ]
}
"""

struct NoticeText: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.largeTitle.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
            }
        }
        .padding(64)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfigMissingView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 20) {
            NoticeText(title: "Falta el archivo de juegos", detail: "Crealo en:\n\(url.path)")
                .fixedSize(horizontal: false, vertical: true)
            Text(exampleConfig)
                .font(.system(.title3, design: .monospaced))
                .padding(24)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfigInvalidView: View {
    let url: URL
    let problem: String

    var body: some View {
        NoticeText(title: "No se pudo leer games.json", detail: "\(url.path)\n\n\(problem)")
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 24) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Cargando biblioteca de juegos...")
                    .font(.title2.weight(.medium))
            }
        }
    }
}

struct MessagePanel: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(message)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                Text("✕ Aceptar").font(.title3.weight(.medium)).opacity(0.8)
            }
            .padding(40)
            .frame(maxWidth: 680)
            .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

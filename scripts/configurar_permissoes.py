"""
Injeta as permissões de localização e de serviço em primeiro plano
(necessárias para o rastreamento de rota em segundo plano do modo
Corrida) no android/app/src/main/AndroidManifest.xml gerado
automaticamente pelo `flutter create` no CI.

Roda apenas dentro do GitHub Actions, depois de `flutter create`.
"""

import pathlib
import re
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

PERMISSOES = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.WAKE_LOCK",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
]


def main() -> None:
    if not MANIFEST.exists():
        print(f"ERRO: {MANIFEST} não encontrado.", file=sys.stderr)
        sys.exit(1)

    conteudo = MANIFEST.read_text(encoding="utf-8")

    if "ACCESS_BACKGROUND_LOCATION" in conteudo:
        print("Permissões de localização já configuradas, nada a fazer.")
        return

    linhas_permissao = "\n".join(
        f'    <uses-permission android:name="{p}"/>'
        for p in PERMISSOES
        if f'android:name="{p}"' not in conteudo
    )

    marcador = re.search(r"<application\b", conteudo)
    if not marcador:
        print("ERRO: não encontrei a tag <application> no AndroidManifest.xml.", file=sys.stderr)
        sys.exit(1)

    posicao = marcador.start()
    novo_conteudo = conteudo[:posicao] + linhas_permissao + "\n\n    " + conteudo[posicao:]

    MANIFEST.write_text(novo_conteudo, encoding="utf-8")
    print("Permissões de localização/serviço em primeiro plano adicionadas ao AndroidManifest.xml.")


if __name__ == "__main__":
    main()

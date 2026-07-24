"""
Injeta as permissões de localização e de serviço em primeiro plano
(necessárias para o rastreamento de rota em segundo plano do modo
Corrida) no android/app/src/main/AndroidManifest.xml gerado
automaticamente pelo `flutter create` no CI. Também declara o
`<service>` do flutter_foreground_task com `foregroundServiceType="location"`.

Sem essa declaração de serviço, o Android 14+ pode iniciar o serviço em
primeiro plano normalmente mas sem a prioridade de execução associada a
localização — o sintoma disso é justamente pontos de GPS gravados com
baixa prioridade/precisão enquanto outro app está em primeiro plano,
mesmo com a notificação fixa visível.

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

# Nome fixo do serviço nativo criado pelo plugin flutter_foreground_task.
SERVICO_FOREGROUND_TASK = "com.pravera.flutter_foreground_task.service.ForegroundService"

DECLARACAO_SERVICO = f'''    <service
        android:name="{SERVICO_FOREGROUND_TASK}"
        android:foregroundServiceType="location"
        android:exported="false" />
'''


def _adicionar_permissoes(conteudo: str) -> str:
    if "ACCESS_BACKGROUND_LOCATION" in conteudo:
        return conteudo

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
    return conteudo[:posicao] + linhas_permissao + "\n\n    " + conteudo[posicao:]


def _adicionar_declaracao_servico(conteudo: str) -> str:
    if SERVICO_FOREGROUND_TASK in conteudo:
        return conteudo

    marcador = re.search(r"</application>", conteudo)
    if not marcador:
        print("ERRO: não encontrei a tag </application> no AndroidManifest.xml.", file=sys.stderr)
        sys.exit(1)

    posicao = marcador.start()
    return conteudo[:posicao] + DECLARACAO_SERVICO + conteudo[posicao:]


def main() -> None:
    if not MANIFEST.exists():
        print(f"ERRO: {MANIFEST} não encontrado.", file=sys.stderr)
        sys.exit(1)

    conteudo = MANIFEST.read_text(encoding="utf-8")
    conteudo_original = conteudo

    conteudo = _adicionar_permissoes(conteudo)
    conteudo = _adicionar_declaracao_servico(conteudo)

    if conteudo == conteudo_original:
        print("Permissões e serviço de localização já configurados, nada a fazer.")
        return

    MANIFEST.write_text(conteudo, encoding="utf-8")
    print(
        "Permissões de localização/serviço em primeiro plano e "
        "foregroundServiceType=\"location\" adicionados ao AndroidManifest.xml."
    )


if __name__ == "__main__":
    main()

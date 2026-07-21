"""
Injeta a leitura do key.properties e a signingConfig de release no
build.gradle (ou build.gradle.kts) gerado automaticamente pelo
`flutter create` no CI. Isso garante que TODAS as builds usem a mesma
assinatura, permitindo atualizar o APK no celular sem precisar
desinstalar (o Android recusa updates cuja assinatura mudou).

Detecta automaticamente se o projeto usa Groovy (build.gradle, padrão
até o Flutter ~3.3x) ou Kotlin DSL (build.gradle.kts, padrão a partir
do Flutter 3.44) e aplica a sintaxe correta para cada caso.

Roda apenas dentro do GitHub Actions, depois de `flutter create`.
"""

import pathlib
import re
import sys

GROOVY_FILE = pathlib.Path("android/app/build.gradle")
KOTLIN_FILE = pathlib.Path("android/app/build.gradle.kts")


def patch_groovy(caminho: pathlib.Path) -> None:
    conteudo = caminho.read_text(encoding="utf-8")

    if "keystoreProperties" in conteudo:
        print("Assinatura já configurada, nada a fazer.")
        return

    keystore_properties_block = """
def keystorePropertiesFile = rootProject.file('key.properties')
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
"""
    signing_configs_block = """
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
"""

    marcador_android = "\nandroid {"
    if marcador_android not in conteudo:
        print("ERRO: não encontrei o bloco `android {` no build.gradle.", file=sys.stderr)
        sys.exit(1)

    conteudo = conteudo.replace(marcador_android, keystore_properties_block + marcador_android, 1)
    conteudo = conteudo.replace("android {", "android {" + signing_configs_block, 1)

    # Casa "signingConfig signingConfigs.debug" OU "signingConfig = signingConfigs.debug".
    padrao = re.compile(r"signingConfig\s*=?\s*signingConfigs\.debug")
    conteudo, quantidade = padrao.subn("signingConfig = signingConfigs.release", conteudo, count=1)

    if quantidade == 0:
        print(
            "ERRO: não encontrei a linha 'signingConfig ... signingConfigs.debug' "
            "para substituir (build.gradle Groovy).",
            file=sys.stderr,
        )
        sys.exit(1)

    caminho.write_text(conteudo, encoding="utf-8")
    print("Assinatura de release configurada com sucesso em build.gradle (Groovy).")


def bump_compile_sdk_groovy(caminho: pathlib.Path) -> None:
    """Algumas dependências (ex: geocoding_android) exigem compileSdk >= 34,
    mas o padrão do Flutter às vezes ainda aponta para uma versão mais
    antiga. Fixamos em 36 (a mais recente disponível nos runners do
    GitHub Actions no momento) para evitar esse tipo de erro."""
    conteudo = caminho.read_text(encoding="utf-8")
    padrao = re.compile(r"compileSdk\s+flutter\.compileSdkVersion")
    novo_conteudo, quantidade = padrao.subn("compileSdk 36", conteudo, count=1)
    if quantidade == 0:
        print(
            "ERRO: não encontrei a linha 'compileSdk flutter.compileSdkVersion' "
            "para substituir (build.gradle Groovy). Conteúdo atual abaixo:",
            file=sys.stderr,
        )
        print(conteudo, file=sys.stderr)
        sys.exit(1)
    caminho.write_text(novo_conteudo, encoding="utf-8")
    print("compileSdk fixado em 36 (build.gradle Groovy).")


def patch_kotlin(caminho: pathlib.Path) -> None:
    conteudo = caminho.read_text(encoding="utf-8")

    if "keystoreProperties" in conteudo:
        print("Assinatura já configurada, nada a fazer.")
        return

    # Em Kotlin DSL, `import` só pode ficar no topo do arquivo — por isso
    # vai antes de tudo, inclusive do bloco `plugins { ... }`.
    imports_block = (
        "import java.io.FileInputStream\n"
        "import java.util.Properties\n\n"
    )

    keystore_properties_block = """
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
"""
    signing_configs_block = """
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
"""

    conteudo = imports_block + conteudo

    marcador_android = "\nandroid {"
    if marcador_android not in conteudo:
        print("ERRO: não encontrei o bloco `android {` no build.gradle.kts.", file=sys.stderr)
        sys.exit(1)

    conteudo = conteudo.replace(marcador_android, keystore_properties_block + marcador_android, 1)
    conteudo = conteudo.replace("android {", "android {" + signing_configs_block, 1)

    # Em Kotlin DSL, o padrão gerado costuma ser:
    #   signingConfig = signingConfigs.getByName("debug")
    padrao = re.compile(r'signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)')
    conteudo, quantidade = padrao.subn(
        'signingConfig = signingConfigs.getByName("release")', conteudo, count=1
    )

    if quantidade == 0:
        print(
            "ERRO: não encontrei a linha 'signingConfig = signingConfigs.getByName(\"debug\")' "
            "para substituir (build.gradle.kts Kotlin DSL). O template pode ter mudado — "
            "veja o conteúdo completo impresso no log do build para ajustar o script.",
            file=sys.stderr,
        )
        print("----- build.gradle.kts atual (após imports/blocos já inseridos) -----", file=sys.stderr)
        print(conteudo, file=sys.stderr)
        sys.exit(1)

    caminho.write_text(conteudo, encoding="utf-8")
    print("Assinatura de release configurada com sucesso em build.gradle.kts (Kotlin DSL).")


def bump_compile_sdk_kotlin(caminho: pathlib.Path) -> None:
    """Ver bump_compile_sdk_groovy — mesma ideia, sintaxe Kotlin DSL."""
    conteudo = caminho.read_text(encoding="utf-8")
    padrao = re.compile(r"compileSdk\s*=\s*\S+")
    novo_conteudo, quantidade = padrao.subn("compileSdk = 36", conteudo, count=1)
    if quantidade == 0:
        print(
            "ERRO: não encontrei a linha 'compileSdk = ...' para substituir "
            "(build.gradle.kts Kotlin DSL). Conteúdo atual abaixo:",
            file=sys.stderr,
        )
        print(conteudo, file=sys.stderr)
        sys.exit(1)
    caminho.write_text(novo_conteudo, encoding="utf-8")
    print("compileSdk fixado em 36 (build.gradle.kts Kotlin DSL).")


def main() -> None:
    if KOTLIN_FILE.exists():
        patch_kotlin(KOTLIN_FILE)
        bump_compile_sdk_kotlin(KOTLIN_FILE)
    elif GROOVY_FILE.exists():
        patch_groovy(GROOVY_FILE)
        bump_compile_sdk_groovy(GROOVY_FILE)
    else:
        print(
            f"ERRO: nem {GROOVY_FILE} nem {KOTLIN_FILE} foram encontrados.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()

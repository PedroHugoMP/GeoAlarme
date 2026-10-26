# GeoAlarme para iOS

Aplicativo SwiftUI que monitora uma região circular e notifica quando o iPhone detecta entrada nela. A configuração fica no próprio aparelho; não há backend. O aplicativo requer iOS 17 ou posterior.

## Arquivos

```text
GeoAlarme.xcodeproj/
├── project.pbxproj
└── xcshareddata/xcschemes/GeoAlarme.xcscheme
GeoAlarme/
├── ContentView.swift
├── GeoAlarmeApp.swift
├── Info.plist
├── Models/
│   └── AlarmDestination.swift
└── Services/
    ├── AlarmManager.swift
    ├── LocationManager.swift
    └── NotificationManager.swift
README.md
```

## Abrir e configurar no Xcode

1. Em um Mac com Xcode, abra `GeoAlarme.xcodeproj` (duplo clique no Finder ou **File > Open**).
2. Selecione o target **GeoAlarme** e, em **Signing & Capabilities > Signing**, escolha seu time. O identificador padrão `br.com.geoalarme.app` pode ser trocado por um identificador único, se necessário.
3. Escolha um simulador ou iPhone e use **Product > Build** (ou **Run** para executar). O projeto já define SwiftUI, Swift, iOS 17.0, a scheme compartilhada `GeoAlarme` e as chaves de privacidade em `GeoAlarme/Info.plist`.
4. Não habilite Background Modes / Audio: o app não promete manter áudio executando suspenso, e o monitoramento de região usa Core Location.
5. Não é necessário adicionar arquivo de som: o toque repetitivo no primeiro plano é gerado como áudio PCM em memória e reproduzido com AVFoundation.

## Permissões

Ao ativar o alarme, o app solicita notificações e, em seguida, localização. Autorize notificações e localização **Sempre** quando o iOS oferecer essa opção; dependendo da versão do sistema, pode ser necessário alterar a localização manualmente em **Ajustes > Privacidade e Segurança > Serviços de Localização > GeoAlarme**. O app não pode conceder a própria permissão nem contornar a escolha do usuário.

O monitoramento só é iniciado com Serviços de Localização ligados, autorização `Always`, suporte de monitoramento disponível e raio abaixo do limite informado pelo aparelho. A Apple limita a 20 regiões monitoradas por app; o GeoAlarme usa uma. Se uma permissão for negada, consulte a mensagem no app e atualize-a em Ajustes.

## Instalar em iPhone

1. Conecte e confie no iPhone, selecione-o como destino no Xcode e ative o modo de desenvolvedor se solicitado.
2. Em **Signing & Capabilities**, use uma equipe Apple válida e um identificador de pacote único.
3. Pressione **Run**. Para distribuição a outros aparelhos, use os canais de assinatura/distribuição da Apple.
4. Autorize notificações e localização. Teste com o app ativo inicialmente e mantenha uma distância razoável do destino antes de iniciar o monitoramento.

## Testes

- **Simulador:** no menu **Features > Location**, selecione uma localização ou rota GPX. Regiões podem se comportar de forma diferente de um aparelho real; não use o simulador para garantir confiabilidade em produção.
- **Aparelho:** escolha um destino próximo, defina um raio adequado e atravesse a borda da região com o app ativo e depois em segundo plano. O tempo do evento depende do iOS, sinal e condições de localização.
- Para uma simulação reproduzível, no Xcode use **Debug > Simulate Location** com um GPX que passe de fora para dentro do círculo. A entrada só ocorre quando as coordenadas simuladas cruzam o limite monitorado.

## Limitações e solução de problemas

- Core Location pode atrasar ou não entregar eventos conforme sinal, bateria, permissões, estado do aparelho ou encerramento forçado do app. Não é um serviço de execução garantida.
- O som repetitivo é reproduzido somente enquanto o processo está executando. Suspenso/encerrado, o iOS entrega uma notificação local com som padrão quando possível; isso não é alarme contínuo e pode ser afetado por Foco, modo silencioso, ajustes de notificação e restrições do sistema.
- Sons críticos que ignoram modo silencioso exigem entitlement e autorização específica da Apple; este app não solicita nem promete esse comportamento.
- O raio padrão é 2.000 m e pode ser ajustado entre 100 e 5.000 m; o aparelho pode impor limite inferior. Se exceder o limite informado pelo dispositivo, reduza o raio.
- Se a notificação não chegar, verifique **Ajustes > Notificações > GeoAlarme**. Se a localização não funcionar, confirme serviços ligados e autorização **Sempre**.
- O estado e destino são guardados localmente em `UserDefaults`. Ao reabrir, um alarme ativo é restabelecido somente quando a região e a permissão ainda estão disponíveis. Depois de disparado ou cancelado, pode ser configurado outro destino.
- Uma notificação pode chegar ao entrar na região mesmo quando o processo está suspenso, mas sua entrega e som obedecem às políticas do iOS. Não há garantia de precisão de GPS ou de que o aviso ocorra exatamente na distância configurada.

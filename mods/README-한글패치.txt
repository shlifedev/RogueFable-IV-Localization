Rogue Fable IV 한글패치
====================================================

모든 패치 자산은 게임 설치 루트의 mods\ 폴더 하나에 모여 있다.
원본 게임 폴더(rogue-fable-iv\)는 index.html의 로드 2줄만 추가되어 있다.

[구성]  (전부 mods\ 안)
- ko.js                 : 번역 사전 (영어 원문 → 한국어). 항목을 추가/수정하면 즉시 반영됨.
- i18n.js               : 번역 + 캔버스 텍스트 렌더링 전환 + Galmuri 폰트 주입 + 치트메뉴 로드 (런타임 처리).
- cheat-menu.js         : F9 치트/Tweak 메뉴. i18n.js가 동적 로드한다.
- Galmuri11.woff2       : 한글 픽셀 폰트 (SIL Open Font License, Galmuri-LICENSE.txt 참고).
- Galmuri-LICENSE.txt   : 폰트 라이선스 (재배포 시 동봉 필수).
- reapply-korean-patch.ps1 : 업데이트 후 복구 스크립트.
- (원본) rogue-fable-iv\index.html : 끝부분에 mods\의 두 스크립트를 불러오는 줄 2개만 추가됨 (유일한 원본 수정).

[동작 방식]
원본 게임 코드는 수정하지 않는다. index.html이 게임 로드 마지막에 ../mods/ 의 ko.js·i18n.js를 부르고,
i18n.js가 실행되어
- gs.createText / UIRichText 의 텍스트 렌더링을 캔버스 텍스트(한글 가능)로 바꾸고,
- 화면에 그려지는 영어 문자열을 ko.js 사전으로 치환하며,
- Galmuri 폰트와 치트메뉴(cheat-menu.js)를 주입/로드한다.
사전에 없는 문자열은 영어 그대로 표시되므로(폴백) 게임이 깨지지 않는다.

[게임 업데이트 후 한글이 사라졌을 때]
Steam이 게임을 업데이트하면 index.html이 순정으로 덮어써져 패치 로드 줄이 사라질 수 있다.
이때 아래를 실행하면 복구된다(여러 번 실행해도 안전):

    PowerShell에서:  ./reapply-korean-patch.ps1   (mods 폴더에서 실행)

주의: Steam "게임 파일 무결성 확인"을 돌려도 mods\ 폴더는 원본 외부라 보통 영향받지 않는다.
다만 어떤 이유로든 mods\ 자산이 사라지면 위 스크립트가 git에서 자동 복원을 시도한다(git 저장소인 경우).

[번역 추가/수정]
ko.js 의 "영어원문": "한국어" 형태로 항목을 추가하면 된다.
게임 업데이트로 새 텍스트가 생겨도 그 부분만 영어로 나오고 나머지는 정상이므로,
ko.js에 새 항목만 채워 넣으면 점진적으로 번역을 늘릴 수 있다.

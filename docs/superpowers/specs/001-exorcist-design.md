# exorcist — dokument projektowy (GDD)

*Data: 2026-06-14*

## Wizja

Platformówka 2D (scrolling left-to-right) o egzorcyście awansującym od zakonnika
do papieża. Wyróżnikiem gry jest mechanika, w której **gracz tworzy własny język
zaklęć za pomocą głosu** — dzięki temu każda rozgrywka brzmi inaczej.

## Cztery filary rozgrywki

### 1. Głos jako zaklęcie (rdzeń)

- Każdy znak (symbol w księdze) ma swój **„rytuał inskrypcji"**: przy pierwszym
  odkryciu gracz patrzy na znak i **sam wymyśla, jak go wymówić**. Gra nagrywa to
  brzmienie i wiąże je ze znakiem.
- Rzucanie zaklęcia = odtworzenie zapamiętanego brzmienia. Gra **nie transkrybuje
  mowy** — porównuje nowe nagranie z zapisanym wzorcem gracza według podobieństwa
  dźwiękowego, w ramach tolerancji.
- Konsekwencje projektowe:
  - Brak „poprawnej" wymowy → niezależność od języka i akcentu.
  - Pełna regrywalność — każdy gracz buduje osobisty, niepowtarzalny język zaklęć.
  - Problem techniczny zmienia się z *rozpoznawania mowy* (trudne) w
    *dopasowywanie podobieństwa dźwięku* (bardziej wykonalne).

### 2. Presja pamięci

- Gracz musi pamiętać własne brzmienia — to przeniesienie ciężaru rozgrywki na
  pamięć.
- Księga pozwala **odsłuchać własny wzorzec, ale z ograniczeniem** (np. tylko poza
  walką lub limitowana liczba użyć). W ferworze walki gracz polega na pamięci.

### 3. Walka zręcznościowa + taktyka słabości

- Klasyczna platformówka: ruch, skok, unik; zaklęcia pełnią rolę broni.
- Każdy demon ma **słabość** na konkretne zaklęcie lub meta-zaklęcie. Złe zaklęcie
  daje słaby efekt lub jego brak.
- **Bestiariusze** (księgi o demonach) ujawniają, które zaklęcie działa najlepiej.
  Dobór właściwego zaklęcia to warstwa taktyczna nałożona na zręczność.
- **Meta-zaklęcia** = szybkie combo dwóch zapamiętanych brzmień wypowiedzianych
  po sobie.

### 4. Progresja: zakonnik → papież

Awans w hierarchii kościelnej jest główną osią gry i działa na czterech poziomach:

- **Narracja / świat** — kolejne rangi to kolejne regiony/akty gry i coraz
  groźniejsi przeciwnicy.
- **Gating treści** — ranga odblokowuje potężniejsze księgi (silniejsze zaklęcia
  oraz wiedzę o trudniejszych demonach).
- **Sloty zaklęć** — wyższa ranga = więcej aktywnych zaklęć/meta-zaklęć dostępnych
  naraz.
- **Pasywne zdolności** — np. większa tolerancja wymowy, szybsze rzucanie, więcej
  zdrowia.

## Typy ksiąg (zbierane na poziomach)

- **Księgi zaklęć** — pojedyncze znaki.
- **Księgi meta-zaklęć** — combosy złożone z dwóch znaków.
- **Bestiariusze** — wiedza o słabościach demonów.

## Pętla rozgrywki

1. Eksploracja poziomu (platformówka).
2. Znajdowanie ksiąg.
3. Nauka zaklęć przez rytuał inskrypcji (wymyślenie i nagranie brzmienia).
4. Walka z demonami — dobór i wypowiadanie właściwych zaklęć pod presją zręczności
   i pamięci.
5. Awans w hierarchii → odblokowanie nowych treści, slotów i zdolności.

## Kluczowe ryzyka do rozwiązania w prototypie

1. **Spójność odtwarzania głosu i strojenie tolerancji** — decyduje o „czuciu"
   gry. Za ostra tolerancja = frustracja; za luźna = każdy dźwięk działa. Wymaga
   testów na żywo.
2. **Zależność od mikrofonu** — hałas otoczenia, dostępność, ewentualny tryb bez
   mikrofonu (fallback).
3. **Prywatność** — nagrania głosu przechowywane lokalnie.

## Świadomie odłożone decyzje

- **Technologia / silnik / stack** — wybór silnika gry oraz konkretnego podejścia
  do dopasowania audio zostaje odłożony do etapu planu implementacji.

# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

## Users

General football fans on a Mac who want to check scores, live matches and league standings without opening a browser. The app has to explain itself, because it is meant for people other than its author.

## Product Purpose

Placar is a native macOS football scores app. It shows every match of the day across competitions worldwide, the matches in progress, league rounds and standings, and a match page with events, statistics and match info. Success means a fan finds the match they care about and reads its state at a glance.

## Positioning

A scores app with its own visual identity and no clutter: no ads, banners, promos or upsells. It shows only the matches and their data.

## Operating Context

The window stays open next to other work. Users check it in short bursts during match days, then drill into a single match or league when something happens. Live data refreshes automatically: about every 30 s while matches are in progress, about every 2 min otherwise.

## Capabilities and Constraints

- Three primary destinations: Hoje (matches per day, browsable one week back and forward), Ao vivo (matches in progress) and Ligas (countries, then competitions, then a league's rounds and standings).
- The match page opens inside the main window, not in a modal.
- Users can mark favorite competitions, which are listed first.
- All interface text is in Brazilian Portuguese.
- The app is SwiftUI, targets macOS 14 and is built with a Makefile, with no Xcode project.
- Data comes from public scores feeds. Team and competition logos are remote images.

## Brand Commitments

- Name: Placar.
- Typeface: Score, the app's own font, derived from Archivo under the SIL OFL (Resources/Fonts/Score.ttf). It has weights 400 to 900, widths 82 to 100 and tabular digits by default. Outfit was replaced on 2026-11-15.

## Product Principles

- Content only: never add promotional or decorative noise around the scores.
- Live state is the loudest thing on screen, and everything else steps back.
- Self-explanatory for a first-time user, with no instructions needed.
- Distinct identity: the app must not look like a stock macOS template.

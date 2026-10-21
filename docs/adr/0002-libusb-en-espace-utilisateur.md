# 0002. Accès USB par libusb en espace utilisateur

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

La MP3 e2 expose des interfaces de classe `0xFF` (vendor specific) : macOS ne charge aucun
pilote générique et la console n'apparaît pas comme périphérique MIDI. Il faut un moyen
d'ouvrir l'appareil et de lire ses endpoints. Les options sont une extension noyau, une
extension DriverKit ou une bibliothèque en espace utilisateur.

## Décision

Nous utilisons **libusb** depuis un processus ordinaire : `libusb_claim_interface`,
transferts bulk et de contrôle. Aucun privilège administrateur n'est requis à l'usage.

## Conséquences

- Installation simple : pas d'extension noyau, pas de DriverKit, pas d'approbation système
  autre que l'autorisation de l'élément en arrière-plan.
- Un ancien driver Hercules qui s'approprie l'interface empêche la passerelle de la
  réclamer (message « Impossible de réclamer l'interface »).
- **Pas de portage iPadOS** : libusb s'appuie sur IOKit USB, indisponible sur iOS/iPadOS.
  Un portage passerait par une extension DriverKit (entitlement
  `com.apple.developer.driverkit.transport.usb`, délivré par Apple, iPad à puce M), ou par
  une passerelle sur Mac qui relaie le MIDI par le réseau.

## Alternatives écartées

- **Extension noyau** : dépréciée, installation lourde.
- **DriverKit** : entitlement à obtenir auprès d'Apple, signature obligatoire, bien plus
  de travail pour un démon qui n'a besoin que de lire un endpoint.

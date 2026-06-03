// PieceNode.swift
// SKSpriteNode subclass for a chess piece. Manages damage-state texture swaps
// and the programmatic Critical flicker (alpha oscillation on d2 sprite).
// Phase 1+: full implementation.

import SpriteKit

final class PieceNode: SKSpriteNode {
    private(set) var piece: Piece

    init(piece: Piece, atlas: SKTextureAtlas) {
        self.piece = piece
        let texture = atlas.textureNamed(piece.textureName)
        super.init(texture: texture, color: .clear, size: texture.size())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateDamageState(atlas: SKTextureAtlas) {
        // Phase 1+: swap texture, start/stop Critical flicker
        let texture = atlas.textureNamed(piece.textureName)
        self.texture = texture
    }

    func applyHitFlash() {
        // Phase 1+: brief white flash on damage
    }

    func runDestructionAnimation(completion: @escaping () -> Void) {
        // Phase 1+: explosion particles, then call completion
        completion()
    }
}

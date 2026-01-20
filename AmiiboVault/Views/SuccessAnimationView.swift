//
//  SuccessAnimationView.swift
//  AmiiboVault
//
//  Success animation with checkmark and confetti effect
//

import SwiftUI

struct SuccessAnimationView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiParticles: [ConfettiParticle] = []
    @Binding var isShowing: Bool
    
    let message: String
    
    var body: some View {
        ZStack {
            // Confetti particles - behind checkmark
            ForEach(confettiParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
            
            // Success checkmark circle - in front of confetti
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 80, height: 80)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .onAppear {
            animate()
        }
        .onChange(of: isShowing) { newValue in
            if newValue {
                animate()
            }
        }
    }
    
    private func animate() {
        // Reset states
        scale = 0.5
        opacity = 0
        confettiParticles = []
        
        // Create confetti particles
        createConfetti()
        
        // Animate checkmark
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Animate confetti
        animateConfetti()
        
        // Hide after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isShowing = false
            }
        }
    }
    
    private func createConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .mint]
        let centerX = UIScreen.main.bounds.width / 2
        let centerY = UIScreen.main.bounds.height / 2
        
        // Create more confetti particles for a richer effect
        for i in 0..<50 {
            let angle = Double(i) * (2 * .pi / 50)
            // Vary the distance for more dynamic effect
            let distance: CGFloat = CGFloat.random(in: 80...150)
            let x = centerX + cos(angle) * distance
            let y = centerY + sin(angle) * distance
            
            confettiParticles.append(ConfettiParticle(
                id: UUID(),
                position: CGPoint(x: centerX, y: centerY),
                targetPosition: CGPoint(x: x, y: y),
                color: colors.randomElement() ?? .red,
                size: CGFloat.random(in: 6...14),
                opacity: 1.0
            ))
        }
    }
    
    private func animateConfetti() {
        // Animate confetti with slight delay to create burst effect
        for i in confettiParticles.indices {
            let delay = Double.random(in: 0...0.2)
            withAnimation(.easeOut(duration: Double.random(in: 0.8...1.5)).delay(delay)) {
                confettiParticles[i].position = confettiParticles[i].targetPosition
                confettiParticles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    let targetPosition: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
}

#Preview {
    SuccessAnimationView(isShowing: .constant(true), message: "Added to collection!")
}


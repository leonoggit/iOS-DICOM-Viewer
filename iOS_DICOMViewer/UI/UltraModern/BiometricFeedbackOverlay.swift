//
//  BiometricFeedbackOverlay.swift
//  iOS_DICOMViewer
//
//  Real-time biometric monitoring and adaptive UI responses
//

import SwiftUI
import Combine
import HealthKit

struct BiometricFeedbackOverlay: View {
    let biometrics: BiometricFeedbackSystem
    @State private var pulseAnimation = false
    @State private var wavePhase: CGFloat = 0
    
    var body: some View {
        VStack {
            HStack {
                // Minimized biometric dashboard
                BiometricWidget(biometrics: biometrics)
                    .frame(width: 200, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(stressLevelColor, lineWidth: 2)
                            )
                    )
                    .shadow(color: stressLevelColor.opacity(0.5), radius: 10)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
    
    var stressLevelColor: Color {
        if biometrics.stressLevel < 0.3 {
            return .green
        } else if biometrics.stressLevel < 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct BiometricWidget: View {
    let biometrics: BiometricFeedbackSystem
    @State private var heartbeatScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Heart rate monitor
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .scaleEffect(heartbeatScale)
                        .onAppear {
                            animateHeartbeat()
                        }
                    
                    Text("\(Int(biometrics.heartRate))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("BPM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // Mini heart rate graph
                HeartRateGraph(heartRate: biometrics.heartRate)
                    .frame(height: 20)
            }
            
            Divider()
                .frame(height: 40)
                .background(Color.gray.opacity(0.3))
            
            // Focus indicator
            VStack(spacing: 4) {
                FocusIndicator(level: biometrics.focusLevel)
                    .frame(width: 50, height: 50)
                
                Text("Focus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
    }
    
    func animateHeartbeat() {
        let duration = 60.0 / biometrics.heartRate
        
        withAnimation(.easeInOut(duration: duration * 0.3)) {
            heartbeatScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.3) {
            withAnimation(.easeInOut(duration: duration * 0.7)) {
                heartbeatScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            animateHeartbeat()
        }
    }
}

struct HeartRateGraph: View {
    let heartRate: Double
    @State private var dataPoints: [CGFloat] = Array(repeating: 72, count: 30)
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(dataPoints.count - 1)
                
                for (index, value) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = (value - 60) / 40 // Normalize between 60-100 BPM
                    let y = height - (normalizedValue * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.red, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateData()
            }
        }
    }
    
    func updateData() {
        dataPoints.removeFirst()
        dataPoints.append(CGFloat(heartRate + Double.random(in: -2...2)))
    }
}

struct FocusIndicator: View {
    let level: Float
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .blue.opacity(Double(level)),
                            .cyan.opacity(Double(level) * 0.8),
                            .blue.opacity(Double(level))
                        ]),
                        center: .center
                    ),
                    lineWidth: 4
                )
                .rotationEffect(.degrees(rotationAngle))
            
            // Inner visualization
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan.opacity(Double(level)))
                    .frame(width: 3, height: 10 + (10 * CGFloat(level)))
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            
            // Center indicator
            Circle()
                .fill(Color.white.opacity(Double(level)))
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Floating AI Assistant

struct FloatingAIAssistant: View {
    let suggestions: [AISuggestion]
    let predictedAction: String
    
    @State private var isExpanded = false
    @State private var glowAnimation = false
    @State private var particleSystem = ParticleSystem()
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // AI suggestions panel (when expanded)
            if isExpanded {
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        AISuggestionBubble(suggestion: suggestion)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
            
            // AI orb button
            Button(action: { 
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    // Particle effect background
                    ParticleEffectView(system: particleSystem)
                        .frame(width: 80, height: 80)
                    
                    // Glowing orb
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    .white,
                                    .cyan,
                                    .blue
                                ]),
                                center: .center,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                .blur(radius: 4)
                                .scaleEffect(glowAnimation ? 1.2 : 1.0)
                        )
                    
                    // AI icon
                    Image(systemName: "brain")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
            particleSystem.start()
        }
    }
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let title: String
    let confidence: Float
    let action: () -> Void
}

struct AISuggestionBubble: View {
    let suggestion: AISuggestion
    
    var body: some View {
        Button(action: suggestion.action) {
            HStack {
                Text(suggestion.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                // Confidence indicator
                ConfidenceBar(confidence: suggestion.confidence)
                    .frame(width: 40, height: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConfidenceBar: View {
    let confidence: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange].prefix(Int(confidence * 3)),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(confidence))
            }
        }
    }
}

// MARK: - Voice Command Indicator

struct VoiceCommandIndicator: View {
    @ObservedObject var quantum: QuantumDICOMInterface
    @State private var isListening = false
    @State private var soundWaveAnimation = false
    @State private var recognizedCommand = ""
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                if isListening {
                    // Active voice command UI
                    HStack(spacing: 12) {
                        // Sound wave animation
                        SoundWaveView(isAnimating: soundWaveAnimation)
                            .frame(width: 60, height: 30)
                        
                        // Recognized text
                        Text(recognizedCommand.isEmpty ? "Listening..." : recognizedCommand)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // Cancel button
                        Button(action: stopListening) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
        }
        .padding()
    }
    
    func stopListening() {
        withAnimation {
            isListening = false
            soundWaveAnimation = false
        }
    }
}

struct SoundWaveView: View {
    let isAnimating: Bool
    @State private var amplitudes: [CGFloat] = [0.3, 0.6, 0.4, 0.8, 0.5]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4, height: 30 * amplitudes[index])
                    .animation(
                        isAnimating ?
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1) :
                        .default,
                        value: amplitudes[index]
                    )
            }
        }
        .onAppear {
            if isAnimating {
                animateWaves()
            }
        }
    }
    
    func animateWaves() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            amplitudes = amplitudes.map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }
}

// MARK: - Particle System

struct ParticleSystem {
    var particles: [Particle] = []
    
    mutating func start() {
        for _ in 0..<20 {
            particles.append(Particle())
        }
    }
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint = .zero
        var velocity: CGVector = CGVector(
            dx: CGFloat.random(in: -2...2),
            dy: CGFloat.random(in: -2...2)
        )
        var opacity: Double = 1.0
        var scale: CGFloat = CGFloat.random(in: 0.5...1.5)
    }
}

struct ParticleEffectView: View {
    let system: ParticleSystem
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in system.particles {
                    context.opacity = particle.opacity
                    
                    let rect = CGRect(
                        x: size.width/2 + particle.position.x - 2,
                        y: size.height/2 + particle.position.y - 2,
                        width: 4 * particle.scale,
                        height: 4 * particle.scale
                    )
                    
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.cyan)
                    )
                }
            }
        }
    }
}
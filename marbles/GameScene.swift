//
//  GameScene.swift
//  marbles
//
//  Created by iMac on 6/1/20.
//  Copyright © 2020 Lord Nibbler. All rights reserved.
//

import CoreMotion // track tilt of device
import SpriteKit

// TODO: instead use typealias?
typealias Ball = SKSpriteNode
//class Ball: SKSpriteNode {}

class GameScene: SKScene {
    // various ballTypes to choose from
    let balls = ["ballBlue", "ballGreen", "ballPurple", "ballRed", "ballYellow"]
    
    // record accelerometer data
    var motionManager: CMMotionManager?
    
    // display score at bottom of screen
    let scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Thin")
    
    // keep track of matched balls when tapping in order to
    // avoid removing matched balls more than once
    var matchedBalls = Set<Ball>()
    
    var score = 0 {
        // property observer
        didSet {
            // every time score is set, update scoreLabel's text
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formattedScore = formatter.string(from: score as NSNumber) ?? "0"
            scoreLabel.text = "SCORE: \(formattedScore)"
        }
    }
    
    override func didMove(to view: SKView) {
        /// implement any custom behavior for your scene when it is about
        /// to be presented by a view
        /// use this method to create the scene’s contents.
        
        // center background to fill full screen
        let background = SKSpriteNode(imageNamed: "checkerboard")
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.alpha = 0.2 // decrease transparency
        background.zPosition = -1 // put behind other sprites
        addChild(background)
        
        // add score label to scene
        scoreLabel.fontSize = 72
        scoreLabel.position = CGPoint(x: 20, y: 20)
        scoreLabel.text = "SCORE: 0"
        scoreLabel.zPosition = 100 // above everything
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)
        
        
        // add grid of balls spaced out by cols/rows on screen
        let ball = SKSpriteNode(imageNamed: "ballBlue")
        let ballRadius = ball.frame.width / 2.0
        
        // move from left edge to right edge by ball amount each iteration
        for i in stride(from: ballRadius, to: view.bounds.width - ballRadius, by: ball.frame.width) {
            for j in stride(from: 100, to: view.bounds.height - ballRadius, by: ball.frame.height) {
                let ballType = balls.randomElement()! // balls is NEVER empty
                let ball = Ball(imageNamed: ballType) // new ball from ball type (blue, purple, w/e)
                ball.position = CGPoint(x: i, y: j)
                ball.name = ballType // to track what color
                
                // give ball physics
                ball.physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
                ball.physicsBody?.allowsRotation = false // shine on ball cant rotate
                ball.physicsBody?.restitution = 0 // very hard, not very bouncy
                ball.physicsBody?.friction = 0 // frictionless, sliding around like marbles
                addChild(ball)
            }
        }
        
        // vars for GSL (fragment shader)
        let uniforms: [SKUniform] = [
            SKUniform(name: "u_speed", float: 1),
            SKUniform(name: "u_strength", float: 3),
            SKUniform(name: "u_frequency", float: 20),
        ]
        
        // construct fragment shader for background wobble
        let shader = SKShader(fileNamed: "Background")
        
        // pass values into the shader
        shader.uniforms = uniforms
        
        // set the background's fragment shader
        background.shader = shader
        
        // run the background fragment shader
        background.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi, duration: 10)))
        
        // give balls container to sit inside so they dont roll off the bottom of screen
        physicsBody = SKPhysicsBody(
            edgeLoopFrom: frame.inset(
                by: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)
            )
        )
        
        motionManager = CMMotionManager()
        motionManager?.startAccelerometerUpdates()
        
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if let accelerometerData = motionManager?.accelerometerData {
            // reading y for x, and x for y; because iPad is in landscape mode!
            // multiply by large number because tilt is very broad; makes tilting more sensitive
            // negating, landscape right mode
            //
            // TODO: check left or right orientation and appropriately negate dx or dy
            //
            physicsWorld.gravity = CGVector(
                dx: accelerometerData.acceleration.y * 50,
                dy: accelerometerData.acceleration.x * -50
            )
        }
    }
    
    // NOTE: fastest way to do it; suffers from a small bug
    // even though restitution and friction are very low, sometimes the distance
    // between balls can be tiny but nonzero, and the matchedBalls count ends up <3
//    func getMatches(from node: Ball) {
//        for body in node.physicsBody!.allContactedBodies() {
//            // make sure this is actually a ball that we happen to find in the scene
//            guard let ball = body.node as? Ball else { continue }
//
//            // ensure ball is of the same type (color)
//            guard ball.name == node.name else { continue }
//
//            // found contacted body which is a ball with same color; has is already been matched in this sweep?
//            if !matchedBalls.contains(ball) {
//                matchedBalls.insert(ball)
//
//                // recurse, spread on whole screen until is checks all possible contacted bodies
//                getMatches(from: ball)
//            }
//
//        }
//    }
    
    
    func getMatches(from startBall: Ball) {
        // square the width of ball; big gap for matching area to scan for around space
        let matchWidth = startBall.frame.width * startBall.frame.width * 1.1
        
        // scan all nodes in the entire screen
        for node in children {
            // only consider balls
            guard let ball = node as? Ball else { continue }
            
            // conly consider balls with same color as startBall
            guard ball.name == startBall.name else { continue }
            
            // calculate distance between the two matches
            let dist = distance(from: startBall, to: ball)
            
            // maximum we're willing to check for
            guard dist < matchWidth else { continue }
            
            // found contacted body which is a ball with same color; has is already been matched in this sweep?
            if !matchedBalls.contains(ball) {
                matchedBalls.insert(ball)
                
                // recurse, spread on whole screen until is checks all possible contacted bodies
                getMatches(from: ball)
            }
        }
    }
    
    func distance(from: Ball, to: Ball) -> CGFloat {
        // distance from center of one ball to center of another ball, squared
        return
            (from.position.x - to.position.x) * (from.position.x - to.position.x) +
            (from.position.y - to.position.y) * (from.position.y - to.position.y)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        // where'd they tap
        
        // non tap, ignore it
        guard let position = touches.first?.location(in: self) else { return }
        
        // find the first SKNode tapped at the tap position on screen that was a ball
        // (ball that was tapped instead of background, score label, etc)
        guard let tappedBall = nodes(at: position).first(where: { $0 is Ball }) as? Ball else { return }
        
        // clear any matched balls previously
        matchedBalls.removeAll(keepingCapacity: true)
        
        // find all balls matching the tapped ball
        getMatches(from: tappedBall)
        
        // player must match at least 3 balls in a group
        if matchedBalls.count >= 3 {
            // modify score; dont allow matching more than 16 balls at a time
            score += Int(pow(2, Double(min(matchedBalls.count, 16))))

            for ball in matchedBalls {
                // create explosion particle for each matched ball
                if let particles = SKEmitterNode(fileNamed: "Explosion") {
                    // place particle over ball being destroyed
                    particles.position = ball.position
                    addChild(particles)
                    
                    // sequence to remove emitter node after particles disappear off screen after 3s
                    let removeAfterDead = SKAction.sequence([SKAction.wait(forDuration: 3), SKAction.removeFromParent()])
                    
                    // render the particle emitter
                    particles.run(removeAfterDead)
                }
                
                // remove ball from scene
                ball.removeFromParent()
            }
        }
        
        // when matching large number of balls show OMG
        if matchedBalls.count >= 10 {
            let omg = SKSpriteNode(imageNamed: "omg")
            omg.position = CGPoint(x: frame.midX, y: frame.midY)
            omg.zPosition = 100
            omg.xScale = 0.001
            omg.yScale = 0.001
            addChild(omg)
            
            // scale up to 100% and fade in in 1/4 of a second
            let appear = SKAction.group([SKAction.scale(to: 1, duration: 0.25), SKAction.fadeIn(withDuration: 0.25)])
            
            // scale up to 200% and fade out in 1/4 of a second
            let disappear = SKAction.group([SKAction.scale(to: 2, duration: 0.25), SKAction.fadeOut(withDuration: 0.25)])
            
            // fade in, pause, fade out
            let sequence = SKAction.sequence([appear, SKAction.wait(forDuration: 0.25), disappear])
            
            omg.run(sequence)
        }
    }
}

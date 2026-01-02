
import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - Elementos UI
    var jumpSoundPlayer: AVAudioPlayer?   // sonidos
    var gameOverSoundPlayer: AVAudioPlayer?
        
    var player: UIView!
    var platforms: [UIView] = []
    var scoreLabel: UILabel!
    var menuView: UIView! // El Popup
    var cloudViews: [UILabel] = []
    
    // MARK: - Parámetros (Tus valores originales)
    var gameTimer: CADisplayLink?
    var velocityY: CGFloat = 0
    let gravity: CGFloat = 0.8
    let jumpForce: CGFloat = -20
    var score = 0 {
        didSet { scoreLabel.text = "Score: \(score)" }
    }
    
    var isPlaying = false
    var isMovingLeft = false
    var isMovingRight = false

    // MARK: - Inicio
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
        createClouds()
        createInitialPlatforms()
        createPlayer()
        setupStartMenu() // Creamos el menú al final para que quede encima
        animateMenuFloating()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error al configurar la sesión de audio: \(error)")
        }
    }

    func setupBaseUI() {
        view.backgroundColor = UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
        
        scoreLabel = UILabel(frame: CGRect(x: 0, y: 60, width: view.frame.width, height: 40))
        scoreLabel.textAlignment = .center
        scoreLabel.font = .boldSystemFont(ofSize: 40)
        scoreLabel.text = "Score: 0"
        scoreLabel.textColor = .white
        view.addSubview(scoreLabel)
        
        createControls()
    }

    // MARK: - Configuración del Popup (Igual a tu foto)
    func setupStartMenu() {
        menuView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 350))
        menuView.center = view.center
        menuView.backgroundColor = .white
        menuView.layer.cornerRadius = 30
//        menuView.layer.shadowOpacity = 0.3
//        menuView.layer.shadowRadius = 10
        
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 40, width: 260, height: 50))
        titleLabel.text = "🚀 Jump Up!"
        titleLabel.font = .boldSystemFont(ofSize: 32)
        titleLabel.textAlignment = .center
        menuView.addSubview(titleLabel)
        
        let subTitle = UILabel(frame: CGRect(x: 20, y: 110, width: 260, height: 80))
        subTitle.text = "Salta de plataforma en plataforma\nUsa las flechas para moverte\n¡No caigas al vacío!"
        subTitle.numberOfLines = 0
        subTitle.textColor = .darkGray
        subTitle.textAlignment = .center
        menuView.addSubview(subTitle)
        
        let startBtn = UIButton(frame: CGRect(x: 40, y: 240, width: 220, height: 60))
        startBtn.backgroundColor = .systemGreen
        startBtn.setTitle("COMENZAR", for: .normal)
        startBtn.titleLabel?.font = .boldSystemFont(ofSize: 20)
        startBtn.layer.cornerRadius = 30
        startBtn.addTarget(self, action: #selector(startGameAction), for: .touchUpInside)
        menuView.addSubview(startBtn)
        
        let bestScoreSaved = UserDefaults.standard.integer(forKey: "highScore")

        let bestScoreLabel = UILabel(frame: CGRect(x: 20, y: 190, width: 260, height: 30))
        bestScoreLabel.text = "Mejor puntuación: \(bestScoreSaved)"
        bestScoreLabel.textColor = .systemOrange
        bestScoreLabel.font = .boldSystemFont(ofSize: 18)
        bestScoreLabel.textAlignment = .center
        
        menuView.layer.shouldRasterize = true
        menuView.layer.rasterizationScale = UIScreen.main.scale
        menuView.addSubview(bestScoreLabel)
        
        view.addSubview(menuView)
    }
    
    
    func animateMenuFloating() {       // efecto flotante del Mensaje Comenzar
    UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction], animations: {
            self.menuView.center.y -= 10
        }, completion: nil)
    }

    
    @objc func startGameAction() {
        
        UIView.animate(withDuration: 0.3) {
            self.menuView.alpha = 0
        }
        // 1. Resetear Estado
        score = 0
        velocityY = 0
        isPlaying = true
        
        // 2. Posicionar personajes (Baja desde arriba sobre el palo)
        player.center = CGPoint(x: view.center.x, y: 100)
        player.isHidden = false
        
        // 3. Ocultar Menú
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.menuView.isHidden = true
            }
        
        // 4. Iniciar Timer de forma segura
        gameTimer?.invalidate()
        gameTimer = CADisplayLink(target: self, selector: #selector(gameLoop))
        gameTimer?.preferredFramesPerSecond = 40
        gameTimer?.add(to: .main, forMode: .common)
    }

    @objc func gameLoop() {
        guard isPlaying else { return }
        
        // 1. Física y Movimiento del Jugador
        velocityY += gravity
        player.center.y += velocityY
        
        if isMovingLeft { player.center.x -= 8 }
        if isMovingRight { player.center.x += 8 }
        
        // Wrap around (Atravesar paredes)
        if player.center.x < 0 { player.center.x = view.frame.width }
        if player.center.x > view.frame.width { player.center.x = 0 }
        
        // 2. Colisiones con Plataformas (Solo cuando cae)
        if velocityY > 0 {
            for platform in platforms {
                if player.frame.intersects(platform.frame) {
                    velocityY = jumpForce
                    score += 10
                    jumpSoundPlayer?.currentTime = 0
                    jumpSoundPlayer?.play()
                    
                    // Animación de rebote (Squash)
                    UIView.animate(withDuration: 0.1, animations: {
                        self.player.transform = CGAffineTransform(scaleX: 1.3, y: 0.8)
                    }) { _ in
                        UIView.animate(withDuration: 0.1) { self.player.transform = .identity }
                    }
                    break
                }
            }
        }
        
        // 3. Mover Plataformas (Optimizando acceso a memoria)
        for p in platforms {
            p.frame.origin.y += 2
            if p.frame.origin.y > view.frame.height {
                p.frame.origin.y = -20
                p.frame.origin.x = CGFloat.random(in: 20...view.frame.width-100)
            }
        }
        
        // 4. MOVIMIENTO DE NUBES OPTIMIZADO (Sin usar tags ni subviews)
        for cloud in cloudViews {
            cloud.frame.origin.y += 0.5
            if cloud.frame.origin.y > view.frame.height {
                cloud.frame.origin.y = -120
                cloud.frame.origin.x = CGFloat.random(in: -50...view.frame.width)
            }
        }
        
        // 5. Game Over
        if player.frame.origin.y > view.frame.height {
            triggerGameOver()
        }
    }
    

    func triggerGameOver() {
        isPlaying = false
        gameTimer?.invalidate()
        
        // 1. Recuperamos el récord actual de la memoria (UserDefaults)
        // Usamos 'let' para declarar la variable dentro de este ámbito
        let highScore = UserDefaults.standard.integer(forKey: "highScore")
        
        // 2. Comparamos con el puntaje actual
        if score > highScore {
            // Si el jugador superó su récord, guardamos el nuevo
            UserDefaults.standard.set(score, forKey: "highScore")
            print("¡Nuevo récord guardado: \(score)!")
        }
        
        // 3. Mostramos el menú
        menuView.isHidden = false
        menuView.transform = .identity
        menuView.isHidden = false
        menuView.alpha = 1
        menuView.isUserInteractionEnabled = true
    }

    // MARK: - Creación de Objetos
    func createPlayer() {
        player = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        player.backgroundColor = .orange
        player.layer.cornerRadius = 20
        let lbl = UILabel(frame: player.bounds)
        lbl.text = "😎"
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 25)
        player.addSubview(lbl)
        view.addSubview(player)
        player.isHidden = true // Oculto hasta que empiece
    }

    func createInitialPlatforms() {
        platforms.forEach { $0.removeFromSuperview() }
        platforms.removeAll()
        
        // El "palo" inicial debajo del centro
        let pInicial = UIView(frame: CGRect(x: view.center.x - 50, y: view.frame.height * 0.6, width: 100, height: 15))
        pInicial.backgroundColor = .brown
        pInicial.layer.cornerRadius = 5
        view.addSubview(pInicial)
        platforms.append(pInicial)
        
        let totalPlatforms = 8
        let verticaSpace = view.frame.height / CGFloat(totalPlatforms)
        
        for i in 0..<totalPlatforms {
            _ = CGFloat(i) * verticaSpace
            // ERROR COMÚN: x: CGFloat.random(in: 0...view.frame.width) <-- A veces falta el cierre o el cálculo
            // FORMA CORRECTA:
            
            _ = CGFloat(i * 100 + 50)
            let anchoPlataforma = view.frame.width * 0.2
            let xAleatoria = CGFloat.random(in: 0...(view.frame.width - anchoPlataforma))

            let p = UIView(frame: CGRect(x: xAleatoria, y: CGFloat(i * 150), width: anchoPlataforma, height: 15))
            p.backgroundColor = .brown
            p.layer.cornerRadius = 5
            view.addSubview(p)
            platforms.append(p)
        }
    }

    func createControls() {
        let s: CGFloat = 90   // ajussta el tamaño d los circulos (botons)
        let y = view.frame.height * 0.90
        let left = UIButton(frame: CGRect(x: 90, y: y, width: s, height: s))
        
        left.setTitle("⬅️", for: .normal)
        left.titleLabel?.font = .systemFont(ofSize: s * 0.6, weight: .bold)
        left.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        left.layer.cornerRadius = s/2
        left.addTarget(self, action: #selector(btnDownL), for: .touchDown)
        left.addTarget(self, action: #selector(btnUp), for: [.touchUpInside, .touchUpOutside])
        left.showsTouchWhenHighlighted = true
        left.setTitleColor(.lightGray, for: .highlighted)
       
        view.addSubview(left)
        
        let right = UIButton(frame: CGRect(x: view.frame.width - s - 90, y: y, width: s, height: s))
        right.setTitle("➡️", for: .normal)
        right.titleLabel?.font = .systemFont(ofSize: s * 0.6, weight: .bold)
        right.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        right.layer.cornerRadius = s/2
        right.addTarget(self, action: #selector(btnDownR), for: .touchDown)
        right.addTarget(self, action: #selector(btnUp), for: [.touchUpInside, .touchUpOutside])
        right.showsTouchWhenHighlighted = true
        right.setTitleColor(.lightGray, for: .highlighted)
        view.addSubview(right)
    }
    
    func createClouds() {
        cloudViews.forEach { $0.removeFromSuperview() }
        cloudViews.removeAll()

        for _ in 0..<6 {
            let tamaño = CGFloat.random(in: 70...120)
            let cloud = UILabel(frame: CGRect(x: CGFloat.random(in: 0...view.frame.width),
                                             y: CGFloat.random(in: 0...view.frame.height),
                                             width: tamaño * 1.5, height: tamaño))
            cloud.text = "☁️"
            cloud.font = .systemFont(ofSize: tamaño)
            cloud.alpha = 0.9
            
            view.insertSubview(cloud, at: 0) // Directamente al fondo
            cloudViews.append(cloud) // Referencia guardada
        }
    }

    @objc func btnDownL() { isMovingLeft = true }
    @objc func btnDownR() { isMovingRight = true }
    @objc func btnUp() { isMovingLeft = false; isMovingRight = false }
}

#!/bin/bash
# Update system
yum update -y

# Install Docker
yum install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Git
yum install git -y

# Create app directory
mkdir -p /opt/tictactoe
cd /opt/tictactoe

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# Create nginx.conf
cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Health check endpoint for ALB
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Create index.html (Your Tic-Tac-Toe game)
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tic-Tac-Toe Game</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }

        .container {
            text-align: center;
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
        }

        h1 {
            color: #333;
            margin-bottom: 20px;
            font-size: 2.5em;
        }

        .game-info {
            margin-bottom: 20px;
            font-size: 1.3em;
            color: #555;
            min-height: 30px;
        }

        .current-player {
            font-weight: bold;
            color: #667eea;
        }

        .board {
            display: grid;
            grid-template-columns: repeat(3, 120px);
            grid-template-rows: repeat(3, 120px);
            gap: 10px;
            margin: 0 auto 30px;
            perspective: 1000px;
        }

        .cell {
            background: linear-gradient(145deg, #f0f0f0, #ffffff);
            border: none;
            border-radius: 10px;
            font-size: 3em;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }

        .cell:hover:not(.taken) {
            background: linear-gradient(145deg, #e0e0e0, #f5f5f5);
            transform: scale(1.05);
            box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
        }

        .cell.taken {
            cursor: not-allowed;
        }

        .cell.x {
            color: #667eea;
            animation: popIn 0.3s ease;
        }

        .cell.o {
            color: #f093fb;
            animation: popIn 0.3s ease;
        }

        .cell.winner {
            background: linear-gradient(145deg, #ffd89b, #19547b);
            animation: winPulse 0.6s ease infinite;
        }

        @keyframes popIn {
            0% {
                transform: scale(0);
            }
            50% {
                transform: scale(1.1);
            }
            100% {
                transform: scale(1);
            }
        }

        @keyframes winPulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(1.05);
            }
        }

        .controls {
            display: flex;
            gap: 15px;
            justify-content: center;
            margin-top: 20px;
        }

        button.reset-btn, button.mode-btn {
            padding: 12px 30px;
            font-size: 1.1em;
            border: none;
            border-radius: 25px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: 600;
        }

        .reset-btn {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }

        .reset-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .mode-btn {
            background: linear-gradient(135deg, #f093fb, #f5576c);
            color: white;
        }

        .mode-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(240, 147, 251, 0.4);
        }

        .score-board {
            display: flex;
            justify-content: space-around;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 2px solid #eee;
        }

        .score {
            text-align: center;
        }

        .score-label {
            font-size: 0.9em;
            color: #888;
            margin-bottom: 5px;
        }

        .score-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }

        .mode-indicator {
            margin-bottom: 15px;
            font-size: 1em;
            color: #764ba2;
            font-weight: 600;
        }

        .instance-info {
            margin-top: 20px;
            font-size: 0.8em;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎮 Tic-Tac-Toe</h1>
        <div class="mode-indicator" id="modeIndicator">Mode: Player vs Player</div>
        <div class="game-info" id="gameInfo">
            <span class="current-player">Player X's Turn</span>
        </div>
        
        <div class="board" id="board">
            <button class="cell" data-index="0"></button>
            <button class="cell" data-index="1"></button>
            <button class="cell" data-index="2"></button>
            <button class="cell" data-index="3"></button>
            <button class="cell" data-index="4"></button>
            <button class="cell" data-index="5"></button>
            <button class="cell" data-index="6"></button>
            <button class="cell" data-index="7"></button>
            <button class="cell" data-index="8"></button>
        </div>

        <div class="controls">
            <button class="reset-btn" id="resetBtn">🔄 New Game</button>
            <button class="mode-btn" id="modeBtn">🤖 Play vs AI</button>
        </div>

        <div class="score-board">
            <div class="score">
                <div class="score-label">Player X</div>
                <div class="score-value" id="scoreX">0</div>
            </div>
            <div class="score">
                <div class="score-label">Draws</div>
                <div class="score-value" id="scoreDraw">0</div>
            </div>
            <div class="score">
                <div class="score-label">Player O</div>
                <div class="score-value" id="scoreO">0</div>
            </div>
        </div>

        <div class="instance-info">
            Served via AWS ALB + EC2 + Docker
        </div>
    </div>

    <script>
        let board = ['', '', '', '', '', '', '', '', ''];
        let currentPlayer = 'X';
        let gameActive = true;
        let aiMode = false;
        let scores = { X: 0, O: 0, draw: 0 };

        const winningConditions = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ];

        const cells = document.querySelectorAll('.cell');
        const gameInfo = document.getElementById('gameInfo');
        const resetBtn = document.getElementById('resetBtn');
        const modeBtn = document.getElementById('modeBtn');
        const modeIndicator = document.getElementById('modeIndicator');
        const scoreX = document.getElementById('scoreX');
        const scoreO = document.getElementById('scoreO');
        const scoreDraw = document.getElementById('scoreDraw');

        cells.forEach(cell => cell.addEventListener('click', handleCellClick));
        resetBtn.addEventListener('click', resetGame);
        modeBtn.addEventListener('click', toggleMode);

        function handleCellClick(e) {
            const clickedCell = e.target;
            const clickedCellIndex = parseInt(clickedCell.getAttribute('data-index'));

            if (board[clickedCellIndex] !== '' || !gameActive) {
                return;
            }

            updateCell(clickedCell, clickedCellIndex);
            checkResult();

            if (gameActive && aiMode && currentPlayer === 'O') {
                setTimeout(makeAIMove, 500);
            }
        }

        function updateCell(cell, index) {
            board[index] = currentPlayer;
            cell.textContent = currentPlayer;
            cell.classList.add('taken', currentPlayer.toLowerCase());
        }

        function changePlayer() {
            currentPlayer = currentPlayer === 'X' ? 'O' : 'X';
            gameInfo.innerHTML = `<span class="current-player">Player ${currentPlayer}'s Turn</span>`;
        }

        function checkResult() {
            let roundWon = false;
            let winningCombination = [];

            for (let i = 0; i < winningConditions.length; i++) {
                const [a, b, c] = winningConditions[i];
                if (board[a] && board[a] === board[b] && board[a] === board[c]) {
                    roundWon = true;
                    winningCombination = [a, b, c];
                    break;
                }
            }

            if (roundWon) {
                gameInfo.innerHTML = `🎉 Player ${currentPlayer} Wins!`;
                gameActive = false;
                scores[currentPlayer]++;
                updateScoreBoard();
                highlightWinningCells(winningCombination);
                return;
            }

            if (!board.includes('')) {
                gameInfo.innerHTML = '🤝 It\'s a Draw!';
                gameActive = false;
                scores.draw++;
                updateScoreBoard();
                return;
            }

            changePlayer();
        }

        function highlightWinningCells(combination) {
            combination.forEach(index => {
                cells[index].classList.add('winner');
            });
        }

        function makeAIMove() {
            if (!gameActive) return;
            let move = findBestMove();
            if (move !== -1) {
                const cell = cells[move];
                updateCell(cell, move);
                checkResult();
            }
        }

        function findBestMove() {
            for (let i = 0; i < 9; i++) {
                if (board[i] === '') {
                    board[i] = 'O';
                    if (checkWinForPlayer('O')) {
                        board[i] = '';
                        return i;
                    }
                    board[i] = '';
                }
            }

            for (let i = 0; i < 9; i++) {
                if (board[i] === '') {
                    board[i] = 'X';
                    if (checkWinForPlayer('X')) {
                        board[i] = '';
                        return i;
                    }
                    board[i] = '';
                }
            }

            if (board[4] === '') return 4;

            const corners = [0, 2, 6, 8];
            const availableCorners = corners.filter(i => board[i] === '');
            if (availableCorners.length > 0) {
                return availableCorners[Math.floor(Math.random() * availableCorners.length)];
            }

            const available = board.map((val, idx) => val === '' ? idx : null).filter(val => val !== null);
            return available.length > 0 ? available[Math.floor(Math.random() * available.length)] : -1;
        }

        function checkWinForPlayer(player) {
            return winningConditions.some(condition => {
                return condition.every(index => board[index] === player);
            });
        }

        function resetGame() {
            board = ['', '', '', '', '', '', '', '', ''];
            currentPlayer = 'X';
            gameActive = true;
            gameInfo.innerHTML = '<span class="current-player">Player X\'s Turn</span>';
            
            cells.forEach(cell => {
                cell.textContent = '';
                cell.classList.remove('taken', 'x', 'o', 'winner');
            });
        }

        function toggleMode() {
            aiMode = !aiMode;
            modeBtn.textContent = aiMode ? '👥 Play vs Player' : '🤖 Play vs AI';
            modeIndicator.textContent = aiMode ? 'Mode: Player vs AI' : 'Mode: Player vs Player';
            resetGame();
        }

        function updateScoreBoard() {
            scoreX.textContent = scores.X;
            scoreO.textContent = scores.O;
            scoreDraw.textContent = scores.draw;
        }
    </script>
</body>
</html>
HTMLEOF

# Build and run Docker container
docker build -t tictactoe-game .
docker run -d -p 80:80 --name tictactoe --restart unless-stopped tictactoe-game

# Install CloudWatch agent (optional for monitoring)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm


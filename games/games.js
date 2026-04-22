const games = [
    {
        id: 'snake',
        title: 'Classic Snake',
        category: 'arcade',
        description: 'Guide the snake to eat the apples and grow longer. Don\'t hit the walls or yourself!',
        controls: ['arrows'],
        thumbnail: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=400&h=300&fit=crop&q=80',
        init: () => window.initSnake()
    },
    {
        id: '2048',
        title: '2048 Puzzle',
        category: 'puzzle',
        description: 'Join the numbers and get to the 2048 tile! Swipe to move all tiles.',
        controls: ['arrows'],
        thumbnail: 'https://images.unsplash.com/photo-1614332287897-cdc485fa562d?w=400&h=300&fit=crop&q=80',
        init: () => window.init2048()
    },
    {
        id: 'tetris',
        title: 'Tetris Block',
        category: 'classic',
        description: 'Stack the blocks to clear lines. Don\'t let the blocks reach the top!',
        controls: ['arrows', 'space'],
        thumbnail: 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=400&h=300&fit=crop&q=80',
        init: () => window.initTetris()
    },
    {
        id: 'minesweeper',
        title: 'Minesweeper',
        category: 'puzzle',
        description: 'Clear the board without clicking on any mines. Use numbers to find clues.',
        controls: ['mouse'],
        thumbnail: 'https://images.unsplash.com/photo-1605142859862-978be7eba909?w=400&h=300&fit=crop&q=80',
        init: () => window.initMinesweeper()
    }
];

let currentGame = null;
let currentCleanup = null;

const gameGrid = document.getElementById('game-grid');
const searchInput = document.getElementById('search-input');
const categoryFilters = document.querySelectorAll('#category-filters button');
const gameModal = document.getElementById('game-modal');
const closeModal = document.getElementById('close-modal');
const startGameBtn = document.getElementById('start-game-btn');
const gameOverlay = document.getElementById('game-overlay');

function renderGames(filter = 'all', search = '') {
    gameGrid.innerHTML = '';
    const filtered = games.filter(g => {
        const matchesFilter = filter === 'all' || g.category === filter;
        const matchesSearch = g.title.toLowerCase().includes(search.toLowerCase());
        return matchesFilter && matchesSearch;
    });

    filtered.forEach(game => {
        const card = document.createElement('div');
        card.className = 'game-card bg-gray-900 rounded-xl overflow-hidden border border-gray-800 cursor-pointer shadow-lg';
        card.innerHTML = `
            <div class="h-32 bg-gray-800 relative">
                <img src="${game.thumbnail}" alt="${game.title}" class="w-full h-full object-cover opacity-80">
                <div class="absolute inset-0 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity bg-black/40">
                    <i class="fas fa-play-circle text-4xl text-white"></i>
                </div>
            </div>
            <div class="p-4">
                <h3 class="font-bold text-sm mb-1">${game.title}</h3>
                <span class="text-[10px] uppercase text-indigo-400 font-bold">${game.category}</span>
            </div>
        `;
        card.onclick = () => openGame(game);
        gameGrid.appendChild(card);
    });
}

function openGame(game) {
    currentGame = game;
    document.getElementById('modal-title').textContent = game.title;
    document.getElementById('game-category').textContent = game.category;
    document.getElementById('game-description').textContent = game.description;

    const controlsContainer = document.getElementById('game-controls');
    controlsContainer.innerHTML = '';
    game.controls.forEach(ctrl => {
        const icon = document.createElement('i');
        if (ctrl === 'arrows') icon.className = 'fas fa-arrows-alt text-gray-400';
        else if (ctrl === 'space') icon.className = 'fas fa-keyboard text-gray-400';
        else if (ctrl === 'mouse') icon.className = 'fas fa-mouse text-gray-400';
        controlsContainer.appendChild(icon);
    });

    gameModal.classList.remove('hidden');
    gameOverlay.classList.remove('hidden');

    // Reset best score display
    const bestScore = localStorage.getItem(`bestScore_${game.id}`) || 0;
    document.getElementById('best-score').textContent = bestScore;
}

function closeGameModal() {
    gameModal.classList.add('hidden');
    if (currentCleanup) {
        currentCleanup();
        currentCleanup = null;
    }
}

startGameBtn.onclick = () => {
    gameOverlay.classList.add('hidden');
    if (currentGame && currentGame.init) {
        currentCleanup = currentGame.init();
    }
};

closeModal.onclick = closeGameModal;
gameModal.onclick = (e) => {
    if (e.target === gameModal) closeGameModal();
};

searchInput.oninput = (e) => {
    const activeCategory = document.querySelector('#category-filters .active-filter').dataset.category;
    renderGames(activeCategory, e.target.value);
};

categoryFilters.forEach(btn => {
    btn.onclick = () => {
        categoryFilters.forEach(b => {
            b.classList.remove('active-filter', 'bg-indigo-600', 'text-white');
            b.classList.add('bg-gray-800', 'text-gray-300');
        });
        btn.classList.add('active-filter', 'bg-indigo-600', 'text-white');
        btn.classList.remove('bg-gray-800', 'text-gray-300');
        renderGames(btn.dataset.category, searchInput.value);
    };
});

// Initial render
renderGames();

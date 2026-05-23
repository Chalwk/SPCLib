(function() {
    function createNavAndFooter() {
        const container = document.querySelector('.container');
        if (!container) return;
        if (document.querySelector('.nav-bar')) return;

        const currentPath = window.location.pathname;
        const isInTools = currentPath.includes('/tools/');

        let homeUrl, banUrl;
        if (isInTools) {
            homeUrl = '../index.html';
            banUrl = 'bans.html';
        } else {
            homeUrl = 'index.html';
            banUrl = 'tools/bans.html';
        }

        const navItems = [];
        const isHome = currentPath.endsWith('index.html') || currentPath === '/' || currentPath.endsWith('/');
        if (!isHome) {
            navItems.push({ text: '🏠 Home', url: homeUrl, external: false });
        }

        const isBans = currentPath.endsWith('bans.html');
        if (!isBans) {
            navItems.push({ text: '🛡️ Ban Registry', url: banUrl, external: false });
        }

        navItems.push({
            text: '⭐ GitHub',
            url: 'https://github.com/Chalwk/SPCLib',
            external: true
        });

        const nav = document.createElement('div');
        nav.className = 'nav-bar';
        nav.innerHTML = navItems.map(item => {
            if (item.external) {
                return `<a href="${item.url}" target="_blank" rel="noopener noreferrer">${item.text}</a>`;
            } else {
                return `<a href="${item.url}">${item.text}</a>`;
            }
        }).join('');

        const footer = document.createElement('footer');
        footer.innerHTML = `<div>© 2026 Jericho Crosby (<a href="https://github.com/Chalwk" target="_blank">Chalwk</a>) · SPCLib <br>
<a href="https://github.com/Chalwk/SPCLib" target="_blank">GitHub Repository</a> · 
<a href="https://discord.gg/D76H7RVPC9" target="_blank">Discord</a> · 
<a href="mailto:chalwk.dev@gmail.com">Email</a><br>
Halo is a trademark of Microsoft. This project is not endorsed by Microsoft.</div>`;

        if (container.firstChild) {
            container.insertBefore(nav, container.firstChild);
        } else {
            container.appendChild(nav);
        }
        container.appendChild(footer);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createNavAndFooter);
    } else {
        createNavAndFooter();
    }
})();
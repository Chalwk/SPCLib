(function() {
    function addHomeButton() {
        const container = document.querySelector('.container');
        if (!container) return;
        if (document.querySelector('.home-button-wrapper')) return;

        const currentPath = window.location.pathname;
        const isInTools = currentPath.includes('/tools/');
        let homeUrl = isInTools ? '../index.html' : 'index.html';

        const wrapper = document.createElement('div');
        wrapper.className = 'home-button-wrapper';
        const homeLink = document.createElement('a');
        homeLink.href = homeUrl;
        homeLink.className = 'home-btn';
        homeLink.innerHTML = '🏠 Home';
        wrapper.appendChild(homeLink);

        container.insertBefore(wrapper, container.firstChild);
    }

    function createFooter() {
        const container = document.querySelector('.container');
        if (!container) return;
        if (document.querySelector('footer')) return;

        const footer = document.createElement('footer');
        footer.innerHTML = `
            <div>© 2026 Jericho Crosby (<a href="https://github.com/Chalwk" target="_blank">Chalwk</a>) · SPCLib <br>
            <a href="https://github.com/Chalwk/SPCLib" target="_blank">GitHub Repository</a> · 
            <a href="https://discord.gg/D76H7RVPC9" target="_blank">Discord</a> · 
            <a href="mailto:chalwk.dev@gmail.com">Email</a><br>
            Halo is a trademark of Microsoft. This project is not endorsed by Microsoft.</div>
        `;
        container.appendChild(footer);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            addHomeButton();
            createFooter();
        });
    } else {
        addHomeButton();
        createFooter();
    }
})();
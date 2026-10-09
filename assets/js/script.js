/* Copyright (c) 2026. Jericho Crosby (Chalwk) */

(function () {
    'use strict';

    function addHomeButton() {
        const container = document.querySelector('.container') || document.querySelector('main');
        if (!container) return;
        if (document.querySelector('.home-button-wrapper')) return;

        const currentPath = window.location.pathname;
        const isInTools = currentPath.includes('/tools/');
        const homeUrl = isInTools ? '../index.html' : 'index.html';

        const wrapper = document.createElement('div');
        wrapper.className = 'home-button-wrapper';

        const homeLink = document.createElement('a');
        homeLink.href = homeUrl;
        homeLink.className = 'home-btn';
        homeLink.setAttribute('aria-label', 'Back to SPCLib homepage');
        homeLink.innerHTML = '🏠 Home';

        wrapper.appendChild(homeLink);
        container.insertBefore(wrapper, container.firstChild);
    }

    function createFooter() {
        const container = document.querySelector('.container') || document.querySelector('main');
        if (!container) return;
        if (document.querySelector('footer[data-spclib]')) return;

        const footer = document.createElement('footer');
        footer.setAttribute('data-spclib', 'true');

        const year = new Date().getFullYear();
        footer.innerHTML = `
            <div>
                © ${year} Jericho Crosby
                (<a href="https://github.com/Chalwk" target="_blank" rel="noopener noreferrer">Chalwk</a>)
                · SPCLib<br>
                <a href="https://github.com/Chalwk/SPCLib" target="_blank" rel="noopener noreferrer">GitHub Repository</a>
                · <a href="https://discord.gg/VAEb4FXU5" target="_blank" rel="noopener noreferrer">Discord</a>
                · <a href="mailto:chalwk.dev@gmail.com">Email</a><br>
                <span style="font-size:0.72rem;opacity:0.75;">
                    Halo is a trademark of Microsoft. This project is not endorsed by Microsoft.
                </span>
            </div>
        `;
        container.appendChild(footer);
    }

    function showToast(message, variant) {
        let toast = document.querySelector('.spclib-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.className = 'spclib-toast';
            toast.setAttribute('role', 'status');
            toast.setAttribute('aria-live', 'polite');
            document.body.appendChild(toast);
        }
        toast.textContent = message;
        toast.className = 'spclib-toast' + (variant ? ' ' + variant : '');
        requestAnimationFrame(() => toast.classList.add('show'));
        clearTimeout(showToast._t);
        showToast._t = setTimeout(() => toast.classList.remove('show'), 2200);
    }

    async function copyToClipboard(text) {
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(text);
            } else {
                const ta = document.createElement('textarea');
                ta.value = text;
                ta.style.position = 'fixed';
                ta.style.opacity = '0';
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
            }
            showToast('📋 Copied to clipboard', 'success');
            return true;
        } catch (err) {
            showToast('❌ Copy failed', 'error');
            return false;
        }
    }

    window.SPCLib = Object.assign(window.SPCLib || {}, {
        showToast,
        copyToClipboard
    });

    function boot() {
        addHomeButton();
        createFooter();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
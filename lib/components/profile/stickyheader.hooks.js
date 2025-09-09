export default {
	mounted() {
		this.sentinel = document.getElementById(this.el.dataset.sentinelId);
		this.showClass = this.el.dataset.showClass.split(' ');
		this.hideClass = this.el.dataset.hideClass.split(' ');
		
		if (this.sentinel) {
			this.observer = new IntersectionObserver(
				(entries) => this.handleIntersection(entries),
				{
					root: null,
					rootMargin: '-60px 0px 0px 0px',
					threshold: 0
				}
			);
			this.observer.observe(this.sentinel);
		}
	},
	
	handleIntersection(entries) {
		const entry = entries[0];
		if (!entry.isIntersecting) {
			// Sentinel is out of view, show sticky header
			this.el.classList.remove(...this.hideClass);
			this.el.classList.add(...this.showClass, 'sticky', 'top-0', 'h-full');
		} else {
			// Sentinel is in view, hide sticky header
			this.el.classList.remove(...this.showClass, 'sticky', 'top-0', 'h-full');
			this.el.classList.add(...this.hideClass);
		}
	},
	
	destroyed() {
		if (this.observer) {
			this.observer.disconnect();
		}
	}
};
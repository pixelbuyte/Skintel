import { PublicPage } from '@/components/PublicPage';

export default function About() {
  return (
    <PublicPage eyebrow="About" title="Why Skintel exists.">
      <p>
        Most people figure out what breaks their skin out by buying ten products, breaking out
        five times, and slowly piecing together which ingredient was the common thread. It takes
        years. It costs hundreds. It rarely gets resolved.
      </p>

      <p>
        Skintel does the bookkeeping for you. You log what you used. You tag what broke you out.
        We surface the ingredients that show up in your breakout products and never in your safe
        ones. That's the whole product.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">What we won't do</h2>
      <p>
        We won't recommend products based on affiliate kickbacks. We won't sell your data to
        brands. We won't make health claims we can't back with your own data. Pattern detection is
        honest — it shows you what's correlated, not what's guaranteed.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Built by one person</h2>
      <p>
        Skintel is a solo project. Email gets a response within a day. Feature requests get read.
        Bug reports get fixed.
      </p>

      <p>
        If that sounds useful, the best way to support the work is to sign up. If it doesn't —
        thanks for reading.
      </p>
    </PublicPage>
  );
}

// Edge Function Supabase — envoie un email via Resend quand une réclamation
// est assignée à un collaborateur. Clé API Resend lue depuis les secrets
// Supabase (jamais exposée côté client).

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { destinataire_email, destinataire_nom, reference, agence, type_plainte, description } = await req.json();

    if (!destinataire_email) {
      return new Response(JSON.stringify({ error: "destinataire_email manquant" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Coris Réclamations <onboarding@resend.dev>",
        to: [destinataire_email],
        subject: `Réclamation ${reference} vous a été assignée`,
        html: `
          <p>Bonjour ${destinataire_nom || ""},</p>
          <p>La réclamation <strong>${reference}</strong> vient de vous être assignée sur la plateforme Coris Réclamations.</p>
          <ul>
            <li><strong>Agence :</strong> ${agence || "-"}</li>
            <li><strong>Nature :</strong> ${type_plainte || "-"}</li>
            <li><strong>Description :</strong> ${description || "-"}</li>
          </ul>
          <p>Merci de vous connecter au tableau de bord pour la traiter.</p>
        `,
      }),
    });

    if (!emailResponse.ok) {
      const errText = await emailResponse.text();
      throw new Error(errText);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

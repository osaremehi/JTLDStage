// ==================== PERSPECTIVE LENSES ====================
// These are thinking lenses the orchestrator uses, NOT independent agents

export interface PerspectiveLens {
  id: string;
  name: string;
  focus: string;
  systemPromptAddition: string;
}

export const PERSPECTIVE_LENSES: PerspectiveLens[] = [
  {
    id: "architect",
    name: "System Architect",
    focus: "System design, integration patterns, scalability, architectural coherence",
    systemPromptAddition: `
When applying the ARCHITECT perspective:
- Look for system-level design patterns and architectural decisions
- Identify integration points and dependencies
- Assess scalability and performance implications
- Check for architectural consistency and coherence
- Look for single points of failure or bottlenecks`,
  },
  {
    id: "security",
    name: "Security Analyst",
    focus: "Security vulnerabilities, access control, data protection, compliance",
    systemPromptAddition: `
When applying the SECURITY perspective:
- Look for security vulnerabilities and attack vectors
- Assess access control and authentication mechanisms
- Check for data exposure risks and privacy concerns
- Verify compliance with security standards
- Identify missing security controls or gaps`,
  },
  {
    id: "business",
    name: "Business Analyst",
    focus: "Business requirements, user stories, acceptance criteria, business logic",
    systemPromptAddition: `
When applying the BUSINESS perspective:
- Verify business requirement fulfillment
- Check user story coverage and acceptance criteria
- Assess business logic completeness
- Identify gaps in business functionality
- Look for requirements that lack implementation`,
  },
  {
    id: "developer",
    name: "Developer",
    focus: "Technical implementation, code quality, API completeness, error handling",
    systemPromptAddition: `
When applying the DEVELOPER perspective:
- Assess technical implementation quality
- Check for code coverage and completeness
- Verify API completeness and consistency
- Look for error handling and edge cases
- Identify technical debt or implementation gaps`,
  },
  {
    id: "user",
    name: "End User Advocate",
    focus: "Usability, accessibility, user experience, intuitive behavior",
    systemPromptAddition: `
When applying the USER perspective:
- Assess usability and user experience flows
- Check for accessibility compliance
- Look for edge cases from user perspective
- Verify intuitive and expected behavior
- Identify confusing or poorly documented features`,
  },
];

export function getPerspectiveById(id: string): PerspectiveLens | undefined {
  return PERSPECTIVE_LENSES.find(p => p.id === id);
}

export function getAllPerspectives(): string[] {
  return PERSPECTIVE_LENSES.map(p => p.id);
}
